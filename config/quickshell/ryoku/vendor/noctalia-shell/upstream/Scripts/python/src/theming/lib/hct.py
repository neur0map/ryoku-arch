"""
HCT (Hue, Chroma, Tone) Color Space Implementation.

Based on Material Color Utilities (Google).
HCT combines CAM16 hue and chroma with CIELAB lightness (L*) for
Material Design 3's perceptual color space.
"""

from __future__ import annotations
import math

# =============================================================================
# Type Definitions
# =============================================================================

RGB = tuple[int, int, int]

# =============================================================================
# CAM16 / HCT Color Space Implementation
# =============================================================================

# sRGB to XYZ matrix (D65 illuminant)
SRGB_TO_XYZ = [
    [0.41233895, 0.35762064, 0.18051042],
    [0.2126, 0.7152, 0.0722],
    [0.01932141, 0.11916382, 0.95034478],
]

# XYZ to sRGB matrix
XYZ_TO_SRGB = [
    [3.2413774792388685, -1.5376652402851851, -0.49885366846268053],
    [-0.9691452513005321, 1.8758853451067872, 0.04156585616912061],
    [0.05562093689691305, -0.20395524564742123, 1.0571799111220335],
]


class ViewingConditions:
    """CAM16 viewing conditions for sRGB display."""
    # White point (D65)
    WHITE_POINT_D65 = [95.047, 100.0, 108.883]

    # Precomputed values for standard conditions
    n = 0.18418651851244416
    aw = 29.980997194447333
    nbb = 1.0169191804458755
    ncb = 1.0169191804458755
    c = 0.69
    nc = 1.0
    fl = 0.3884814537800353
    fl_root = 0.7894826179304937
    z = 1.909169568483652

    # RGB to CAM16 adaptation matrix
    RGB_D = [1.0211931250282205, 0.9862992588498498, 0.9338046048498166]


def _linearize(channel: int) -> float:
    """Convert sRGB channel (0-255) to linear RGB (0-1)."""
    normalized = channel / 255.0
    if normalized <= 0.040449936:
        return normalized / 12.92
    return math.pow((normalized + 0.055) / 1.055, 2.4)


def _delinearize(linear: float) -> int:
    """Convert linear RGB (0-1) to sRGB channel (0-255)."""
    if linear <= 0.0031308:
        normalized = linear * 12.92
    else:
        normalized = 1.055 * math.pow(linear, 1.0 / 2.4) - 0.055
    return max(0, min(255, round(normalized * 255)))


def _matrix_multiply(matrix: list[list[float]], vector: list[float]) -> list[float]:
    """Multiply 3x3 matrix by 3-element vector."""
    return [
        matrix[0][0] * vector[0] + matrix[0][1] * vector[1] + matrix[0][2] * vector[2],
        matrix[1][0] * vector[0] + matrix[1][1] * vector[1] + matrix[1][2] * vector[2],
        matrix[2][0] * vector[0] + matrix[2][1] * vector[1] + matrix[2][2] * vector[2],
    ]


def _signum(x: float) -> float:
    """Return sign of x: -1, 0, or 1."""
    if x < 0:
        return -1.0
    elif x > 0:
        return 1.0
    return 0.0


def _lerp(a: float, b: float, t: float) -> float:
    """Linear interpolation between a and b."""
    return a + (b - a) * t


def _sanitize_degrees(degrees: float) -> float:
    """Ensure degrees is in [0, 360) range."""
    degrees = degrees % 360.0
    if degrees < 0:
        degrees += 360.0
    return degrees


# =============================================================================
# HCT Solver - Ported from Material Color Utilities
# =============================================================================

# Matrices for chromatic adaptation
_SCALED_DISCOUNT_FROM_LINRGB = [
    [0.001200833568784504, 0.002389694492170889, 0.0002795742885861124],
    [0.0005891086651375999, 0.0029785502573438758, 0.0003270666104008398],
    [0.00010146692491640572, 0.0005364214359186694, 0.0032979401770712076],
]

_LINRGB_FROM_SCALED_DISCOUNT = [
    [1373.2198709594231, -1100.4251190754821, -7.278681089101213],
    [-271.815969077903, 559.6580465940733, -32.46047482791194],
    [1.9622899599665666, -57.173814538844006, 308.7233197812385],
]

_Y_FROM_LINRGB = [0.2126, 0.7152, 0.0722]

# Critical planes for bisection (precomputed delinearized values 0-254)
_CRITICAL_PLANES = [
    0.015176349177441876, 0.045529047532325624, 0.07588174588720938,
    0.10623444424209313, 0.13658714259697685, 0.16693984095186062,
    0.19729253930674434, 0.2276452376616281, 0.2579979360165119,
    0.28835063437139563, 0.3188300904430532, 0.350925934958123,
    0.3848314933096426, 0.42057480301049466, 0.458183274052838,
    0.4976837250274023, 0.5391024159806381, 0.5824650784040898,
    0.6277969426914107, 0.6751227633498623, 0.7244668422128921,
    0.775853049866786, 0.829304845476233, 0.8848452951698498,
    0.942497089126609, 1.0022825574869039, 1.0642236851973577,
    1.1283421258858297, 1.1946592148522128, 1.2631959812511864,
    1.3339731595349034, 1.407011200216447, 1.4823302800086415,
    1.5599503113873272, 1.6398909516233677, 1.7221716113234105,
    1.8068114625156377, 1.8938294463134073, 1.9832442801866852,
    2.075074464868551, 2.1693382909216234, 2.2660538449872063,
    2.36523901573795, 2.4669114995532007, 2.5710888059345764,
    2.6777882626779785, 2.7870270208169257, 2.898822059350997,
    3.0131901897720907, 3.1301480604002863, 3.2497121605402226,
    3.3718988244681087, 3.4967242352587946, 3.624204428461639,
    3.754355295633311, 3.887192587735158, 4.022731918402185,
    4.160988767090289, 4.301978482107941, 4.445716283538092,
    4.592217266055746, 4.741496401646282, 4.893568542229298,
    5.048448422192488, 5.20615066083972, 5.3666897647573375,
    5.5300801301023865, 5.696336044816294, 5.865471690767354,
    6.037501145825082, 6.212438385869475, 6.390297286737924,
    6.571091626112461, 6.7548350853498045, 6.941541251256611,
    7.131223617812143, 7.323895587840543, 7.5195704746346665,
    7.7182615035334345, 7.919981813454504, 8.124744458384042,
    8.332562408825165, 8.543448553206703, 8.757415699253682,
    8.974476575321063, 9.194643831691977, 9.417930041841839,
    9.644347703669503, 9.873909240696694, 10.106627003236781,
    10.342513269534024, 10.58158024687427, 10.8238400726681,
    11.069304815507364, 11.317986476196008, 11.569896988756009,
    11.825048221409341, 12.083451977536606, 12.345119996613247,
    12.610063955123938, 12.878295467455942, 13.149826086772048,
    13.42466730586372, 13.702830557985108, 13.984327217668513,
    14.269168601521828, 14.55736596900856, 14.848930523210871,
    15.143873411576273, 15.44220572664832, 15.743938506781891,
    16.04908273684337, 16.35764934889634, 16.66964922287304,
    16.985093187232053, 17.30399201960269, 17.62635644741625,
    17.95219714852476, 18.281524751807332, 18.614349837764564,
    18.95068293910138, 19.290534541298456, 19.633915083172692,
    19.98083495742689, 20.331304511189067, 20.685334046541502,
    21.042933821039977, 21.404114048223256, 21.76888489811322,
    22.137256497705877, 22.50923893145328, 22.884842241736916,
    23.264076429332462, 23.6469514538663, 24.033477234264016,
    24.42366364919083, 24.817520537484558, 25.21505769858089,
    25.61628489293138, 26.021211842414342, 26.429848230738664,
    26.842203703840827, 27.258287870275353, 27.678110301598522,
    28.10168053274597, 28.529008062403893, 28.96010235337422,
    29.39497283293396, 29.83362889318845, 30.276079891419332,
    30.722335150426627, 31.172403958865512, 31.62629557157785,
    32.08401920991837, 32.54558406207592, 33.010999283389665,
    33.4802739966603, 33.953417292456834, 34.430438229418264,
    34.911345834551085, 35.39614910352207, 35.88485700094671,
    36.37747846067349, 36.87402238606382, 37.37449765026789,
    37.87891309649659, 38.38727753828926, 38.89959975977785,
    39.41588851594697, 39.93615253289054, 40.460400508064545,
    40.98864111053629, 41.520882981230194, 42.05713473317016,
    42.597404951718396, 43.141702194811224, 43.6900349931913,
    44.24241185063697, 44.798841244188324, 45.35933162437017,
    45.92389141541209, 46.49252901546552, 47.065252796817916,
    47.64207110610409, 48.22299226451468, 48.808024568002054,
    49.3971762874833, 49.9904556690408, 50.587870934119984,
    51.189430279724725, 51.79514187861014, 52.40501387947288,
    53.0190544071392, 53.637271562750364, 54.259673423945976,
    54.88626804504493, 55.517063457223934, 56.15206766869424,
    56.79128866487574, 57.43473440856916, 58.08241284012621,
    58.734331877617365, 59.39049941699807, 60.05092333227251,
    60.715611475655585, 61.38457167773311, 62.057811747619894,
    62.7353394731159, 63.417162620860914, 64.10328893648692,
    64.79372614476921, 65.48848194977529, 66.18756403501224,
    66.89098006357258, 67.59873767827808, 68.31084450182222,
    69.02730813691093, 69.74813616640164, 70.47333615344107,
    71.20291564160104, 71.93688215501312, 72.67524319850172,
    73.41800625771542, 74.16517879925733, 74.9167682708136,
    75.67278210128072, 76.43322770089146, 77.1981124613393,
    77.96744375590167, 78.74122893956174, 79.51947534912904,
    80.30219030335869, 81.08938110306934, 81.88105503125999,
    82.67721935322541, 83.4778813166706, 84.28304815182372,
    85.09272707154808, 85.90692527145302, 86.72564993000343,
    87.54890820862819, 88.3767072518277, 89.2090541872801,
    90.04595612594655, 90.88742016217518, 91.73345337380438,
    92.58406282226491, 93.43925555268066, 94.29903859396902,
    95.16341895893969, 96.03240364439274, 96.9059996312159,
    97.78421388448044, 98.6670533535366, 99.55452497210776,
]


class HctSolver:
    """
    Solves HCT to RGB conversion with proper gamut mapping.

    Ported from Material Color Utilities (Rust/TypeScript).
    When the requested chroma is out of gamut, this solver finds
    the maximum achievable chroma while preserving the exact hue.
    """

    @staticmethod
    def _sanitize_radians(angle: float) -> float:
        """Ensure angle is in [0, 2π) range."""
        return (angle + math.pi * 8) % (math.pi * 2)

    @staticmethod
    def _true_delinearized(rgb_component: float) -> float:
        """Delinearize RGB component (0-100) to (0-255)."""
        normalized = rgb_component / 100.0
        if normalized <= 0.0031308:
            delinearized = normalized * 12.92
        else:
            delinearized = 1.055 * (normalized ** (1.0 / 2.4)) - 0.055
        return delinearized * 255.0

    @staticmethod
    def _chromatic_adaptation(component: float) -> float:
        """Apply chromatic adaptation."""
        af = abs(component) ** 0.42
        return _signum(component) * 400.0 * af / (af + 27.13)

    @staticmethod
    def _hue_of(linrgb: list[float]) -> float:
        """Calculate hue of linear RGB color in radians."""
        scaled_discount = _matrix_multiply(_SCALED_DISCOUNT_FROM_LINRGB, linrgb)

        r_a = HctSolver._chromatic_adaptation(scaled_discount[0])
        g_a = HctSolver._chromatic_adaptation(scaled_discount[1])
        b_a = HctSolver._chromatic_adaptation(scaled_discount[2])

        # redness-greenness
        a = (11.0 * r_a - 12.0 * g_a + b_a) / 11.0
        # yellowness-blueness
        b = (r_a + g_a - 2.0 * b_a) / 9.0

        return math.atan2(b, a)

    @staticmethod
    def _are_in_cyclic_order(a: float, b: float, c: float) -> bool:
        """Check if a, b, c are in cyclic order."""
        delta_ab = HctSolver._sanitize_radians(b - a)
        delta_ac = HctSolver._sanitize_radians(c - a)
        return delta_ab < delta_ac

    @staticmethod
    def _intercept(source: float, mid: float, target: float) -> float:
        """Solve lerp equation: find t such that lerp(source, target, t) = mid."""
        return (mid - source) / (target - source)

    @staticmethod
    def _lerp_point(source: list[float], t: float, target: list[float]) -> list[float]:
        """Linear interpolation between two 3D points."""
        return [
            source[0] + (target[0] - source[0]) * t,
            source[1] + (target[1] - source[1]) * t,
            source[2] + (target[2] - source[2]) * t,
        ]

    @staticmethod
    def _set_coordinate(source: list[float], coordinate: float,
                        target: list[float], axis: int) -> list[float]:
        """Find point on segment where axis equals coordinate."""
        t = HctSolver._intercept(source[axis], coordinate, target[axis])
        return HctSolver._lerp_point(source, t, target)

    @staticmethod
    def _is_bounded(x: float) -> bool:
        """Check if x is in [0, 100]."""
        return 0.0 <= x <= 100.0

    @staticmethod
    def _nth_vertex(y: float, n: int) -> list[float]:
        """
        Get nth vertex of RGB cube intersection with Y plane.

        Returns [-1, -1, -1] if vertex is outside cube.
        """
        k_r, k_g, k_b = _Y_FROM_LINRGB

        coord_a = 0.0 if n % 4 <= 1 else 100.0
        coord_b = 0.0 if n % 2 == 0 else 100.0

        if n < 4:
            g = coord_a
            b = coord_b
            r = (y - k_g * g - k_b * b) / k_r
            if HctSolver._is_bounded(r):
                return [r, g, b]
            return [-1.0, -1.0, -1.0]
        elif n < 8:
            b = coord_a
            r = coord_b
            g = (y - k_r * r - k_b * b) / k_g
            if HctSolver._is_bounded(g):
                return [r, g, b]
            return [-1.0, -1.0, -1.0]
        else:
            r = coord_a
            g = coord_b
            b = (y - k_r * r - k_g * g) / k_b
            if HctSolver._is_bounded(b):
                return [r, g, b]
            return [-1.0, -1.0, -1.0]

    @staticmethod
    def _bisect_to_segment(y: float, target_hue: float) -> list[list[float]]:
        """Find segment on RGB cube containing target hue."""
        left = [-1.0, -1.0, -1.0]
        right = [-1.0, -1.0, -1.0]
        left_hue = 0.0
        right_hue = 0.0
        initialized = False
        uncut = True

        for n in range(12):
            mid = HctSolver._nth_vertex(y, n)

            if mid[0] < 0:
                continue

            mid_hue = HctSolver._hue_of(mid)

            if not initialized:
                left = mid
                right = mid
                left_hue = mid_hue
                right_hue = mid_hue
                initialized = True
                continue

            if uncut or HctSolver._are_in_cyclic_order(left_hue, mid_hue, right_hue):
                uncut = False

                if HctSolver._are_in_cyclic_order(left_hue, target_hue, mid_hue):
                    right = mid
                    right_hue = mid_hue
                else:
                    left = mid
                    left_hue = mid_hue

        return [left, right]

    @staticmethod
    def _mid_point(a: list[float], b: list[float]) -> list[float]:
        """Calculate midpoint of two 3D points."""
        return [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2, (a[2] + b[2]) / 2]

    @staticmethod
    def _critical_plane_below(x: float) -> int:
        """Get critical plane index below x."""
        return int(math.floor(x - 0.5))

    @staticmethod
    def _critical_plane_above(x: float) -> int:
        """Get critical plane index above x."""
        return int(math.ceil(x - 0.5))

    @staticmethod
    def _bisect_to_limit(y: float, target_hue: float) -> list[float]:
        """
        Find color on RGB cube boundary with exact target hue.

        This is the key function for hue-preserving gamut mapping.
        """
        segment = HctSolver._bisect_to_segment(y, target_hue)
        left = segment[0]
        left_hue = HctSolver._hue_of(left)
        right = segment[1]

        for axis in range(3):
            if abs(left[axis] - right[axis]) > 1e-10:
                if left[axis] < right[axis]:
                    l_plane = HctSolver._critical_plane_below(
                        HctSolver._true_delinearized(left[axis]))
                    r_plane = HctSolver._critical_plane_above(
                        HctSolver._true_delinearized(right[axis]))
                else:
                    l_plane = HctSolver._critical_plane_above(
                        HctSolver._true_delinearized(left[axis]))
                    r_plane = HctSolver._critical_plane_below(
                        HctSolver._true_delinearized(right[axis]))

                for _ in range(8):
                    if abs(r_plane - l_plane) <= 1:
                        break

                    m_plane = int((l_plane + r_plane) / 2)
                    # Clamp to valid index range
                    m_plane = max(0, min(len(_CRITICAL_PLANES) - 1, m_plane))
                    mid_plane_coordinate = _CRITICAL_PLANES[m_plane]
                    mid = HctSolver._set_coordinate(left, mid_plane_coordinate, right, axis)
                    mid_hue = HctSolver._hue_of(mid)

                    if HctSolver._are_in_cyclic_order(left_hue, target_hue, mid_hue):
                        right = mid
                        r_plane = m_plane
                    else:
                        left = mid
                        left_hue = mid_hue
                        l_plane = m_plane

        return HctSolver._mid_point(left, right)

    @staticmethod
    def _inverse_chromatic_adaptation(adapted: float) -> float:
        """Inverse of chromatic adaptation."""
        adapted_abs = abs(adapted)
        base = max(0.0, 27.13 * adapted_abs / (400.0 - adapted_abs))
        return _signum(adapted) * (base ** (1.0 / 0.42))

    @staticmethod
    def _find_result_by_j(hue_radians: float, chroma: float, y: float) -> tuple[int, int, int] | None:
        """
        Try to find exact color with given hue, chroma, and Y.

        Returns None if out of gamut.
        """
        j = math.sqrt(y) * 11.0

        t_inner_coeff = 1.0 / ((1.64 - (0.29 ** ViewingConditions.n)) ** 0.73)
        e_hue = 0.25 * (math.cos(hue_radians + 2.0) + 3.8)
        p1 = e_hue * (50000.0 / 13.0) * ViewingConditions.nc * ViewingConditions.ncb
        h_sin = math.sin(hue_radians)
        h_cos = math.cos(hue_radians)

        for iteration in range(5):
            j_normalized = j / 100.0
            if chroma == 0 or j == 0:
                alpha = 0.0
            else:
                alpha = chroma / math.sqrt(j_normalized)

            t = (alpha * t_inner_coeff) ** (1.0 / 0.9)
            ac = ViewingConditions.aw * (j_normalized ** (1.0 / ViewingConditions.c / ViewingConditions.z))
            p2 = ac / ViewingConditions.nbb
            gamma = 23.0 * (p2 + 0.305) * t / (23.0 * p1 + 11.0 * t * h_cos + 108.0 * t * h_sin)
            a = gamma * h_cos
            b = gamma * h_sin

            r_a = (460.0 * p2 + 451.0 * a + 288.0 * b) / 1403.0
            g_a = (460.0 * p2 - 891.0 * a - 261.0 * b) / 1403.0
            b_a = (460.0 * p2 - 220.0 * a - 6300.0 * b) / 1403.0

            r_cscaled = HctSolver._inverse_chromatic_adaptation(r_a)
            g_cscaled = HctSolver._inverse_chromatic_adaptation(g_a)
            b_cscaled = HctSolver._inverse_chromatic_adaptation(b_a)

            linrgb = _matrix_multiply(_LINRGB_FROM_SCALED_DISCOUNT,
                                      [r_cscaled, g_cscaled, b_cscaled])

            # Check if in gamut
            if linrgb[0] < 0 or linrgb[1] < 0 or linrgb[2] < 0:
                return None

            k_r, k_g, k_b = _Y_FROM_LINRGB
            fnj = k_r * linrgb[0] + k_g * linrgb[1] + k_b * linrgb[2]

            if fnj <= 0:
                return None

            if iteration == 4 or abs(fnj - y) < 0.002:
                if linrgb[0] > 100.01 or linrgb[1] > 100.01 or linrgb[2] > 100.01:
                    return None

                # Convert linear RGB to sRGB
                return (
                    _delinearize(linrgb[0] / 100.0),
                    _delinearize(linrgb[1] / 100.0),
                    _delinearize(linrgb[2] / 100.0),
                )

            # Newton iteration
            j = j - (fnj - y) * j / (2.0 * fnj)

        return None

    @staticmethod
    def solve_to_rgb(hue_degrees: float, chroma: float, tone: float) -> tuple[int, int, int]:
        """
        Solve HCT to RGB with proper gamut mapping.

        If the exact color is out of gamut, finds the maximum achievable
        chroma while preserving the exact hue.
        """
        if chroma < 0.0001 or tone < 0.0001 or tone > 99.9999:
            # Achromatic - just convert tone to gray
            y = lstar_to_y(tone)
            gray = _delinearize(y / 100.0)
            return (gray, gray, gray)

        hue_degrees = _sanitize_degrees(hue_degrees)
        hue_radians = math.radians(hue_degrees)
        # Y is in 0-100 range (same scale as internal linear RGB in the solver)
        y = lstar_to_y(tone)

        # Try to find exact solution
        exact = HctSolver._find_result_by_j(hue_radians, chroma, y)
        if exact is not None:
            return exact

        # Fall back to bisection - find max chroma that preserves hue
        linrgb = HctSolver._bisect_to_limit(y, hue_radians)

        return (
            _delinearize(linrgb[0] / 100.0),
            _delinearize(linrgb[1] / 100.0),
            _delinearize(linrgb[2] / 100.0),
        )


def rgb_to_xyz(r: int, g: int, b: int) -> tuple[float, float, float]:
    """Convert sRGB to CIE XYZ."""
    linear_r = _linearize(r)
    linear_g = _linearize(g)
    linear_b = _linearize(b)
    xyz = _matrix_multiply(SRGB_TO_XYZ, [linear_r, linear_g, linear_b])
    return (xyz[0] * 100, xyz[1] * 100, xyz[2] * 100)


def xyz_to_rgb(x: float, y: float, z: float) -> tuple[int, int, int]:
    """Convert CIE XYZ to sRGB."""
    linear = _matrix_multiply(XYZ_TO_SRGB, [x / 100, y / 100, z / 100])
    return (_delinearize(linear[0]), _delinearize(linear[1]), _delinearize(linear[2]))


def y_to_lstar(y: float) -> float:
    """Convert XYZ Y component to L* (CIELAB lightness / HCT Tone)."""
    if y <= 0:
        return 0.0
    y_normalized = y / 100.0
    if y_normalized <= 0.008856:
        return 903.2962962962963 * y_normalized
    return 116.0 * math.pow(y_normalized, 1.0 / 3.0) - 16.0


def lstar_to_y(lstar: float) -> float:
    """Convert L* (Tone) to XYZ Y component."""
    if lstar <= 0:
        return 0.0
    if lstar > 100:
        lstar = 100.0
    if lstar <= 8.0:
        return lstar / 903.2962962962963 * 100.0
    fy = (lstar + 16.0) / 116.0
    return fy * fy * fy * 100.0


def argb_to_int(r: int, g: int, b: int) -> int:
    """Convert RGB to ARGB integer (alpha = 255)."""
    return (255 << 24) | (r << 16) | (g << 8) | b


def int_to_rgb(argb: int) -> tuple[int, int, int]:
    """Convert ARGB integer to RGB tuple."""
    return ((argb >> 16) & 0xFF, (argb >> 8) & 0xFF, argb & 0xFF)


class Cam16:
    """CAM16 color appearance model representation."""

    def __init__(self, hue: float, chroma: float, j: float, q: float,
                 m: float, s: float, jstar: float, astar: float, bstar: float):
        self.hue = hue
        self.chroma = chroma
        self.j = j  # Lightness
        self.q = q  # Brightness
        self.m = m  # Colorfulness
        self.s = s  # Saturation
        self.jstar = jstar  # CAM16-UCS J*
        self.astar = astar  # CAM16-UCS a*
        self.bstar = bstar  # CAM16-UCS b*

    @classmethod
    def from_rgb(cls, r: int, g: int, b: int) -> 'Cam16':
        """Create CAM16 from sRGB values."""
        x, y, z = rgb_to_xyz(r, g, b)

        r_c = 0.401288 * x + 0.650173 * y - 0.051461 * z
        g_c = -0.250268 * x + 1.204414 * y + 0.045854 * z
        b_c = -0.002079 * x + 0.048952 * y + 0.953127 * z

        r_d = ViewingConditions.RGB_D[0] * r_c
        g_d = ViewingConditions.RGB_D[1] * g_c
        b_d = ViewingConditions.RGB_D[2] * b_c

        r_af = math.pow(ViewingConditions.fl * abs(r_d) / 100.0, 0.42)
        g_af = math.pow(ViewingConditions.fl * abs(g_d) / 100.0, 0.42)
        b_af = math.pow(ViewingConditions.fl * abs(b_d) / 100.0, 0.42)

        r_a = _signum(r_d) * 400.0 * r_af / (r_af + 27.13)
        g_a = _signum(g_d) * 400.0 * g_af / (g_af + 27.13)
        b_a = _signum(b_d) * 400.0 * b_af / (b_af + 27.13)

        a = (11.0 * r_a + -12.0 * g_a + b_a) / 11.0
        b = (r_a + g_a - 2.0 * b_a) / 9.0

        hue_radians = math.atan2(b, a)
        hue = math.degrees(hue_radians)
        if hue < 0:
            hue += 360.0

        u = (20.0 * r_a + 20.0 * g_a + 21.0 * b_a) / 20.0
        p2 = (40.0 * r_a + 20.0 * g_a + b_a) / 20.0
        ac = p2 * ViewingConditions.nbb

        j = 100.0 * math.pow(ac / ViewingConditions.aw, ViewingConditions.c * ViewingConditions.z)
        q = (4.0 / ViewingConditions.c) * math.sqrt(j / 100.0) * (ViewingConditions.aw + 4.0) * ViewingConditions.fl_root

        hue_prime = hue + 360.0 if hue < 20.14 else hue
        e_hue = 0.25 * (math.cos(math.radians(hue_prime) + 2.0) + 3.8)

        t = 50000.0 / 13.0 * ViewingConditions.nc * ViewingConditions.ncb * e_hue * math.sqrt(a * a + b * b) / (u + 0.305)
        alpha = math.pow(t, 0.9) * math.pow(1.64 - math.pow(0.29, ViewingConditions.n), 0.73)
        chroma = alpha * math.sqrt(j / 100.0)

        m = chroma * ViewingConditions.fl_root
        s = 50.0 * math.sqrt((ViewingConditions.c * alpha) / (ViewingConditions.aw + 4.0))

        jstar = (1.0 + 100.0 * 0.007) * j / (1.0 + 0.007 * j)
        mstar = 1.0 / 0.0228 * math.log(1.0 + 0.0228 * m) if m > 0 else 0
        astar = mstar * math.cos(hue_radians)
        bstar = mstar * math.sin(hue_radians)

        return cls(hue, chroma, j, q, m, s, jstar, astar, bstar)

    @classmethod
    def from_jch(cls, j: float, chroma: float, hue: float) -> 'Cam16':
        """Create CAM16 from J (lightness), chroma, and hue."""
        q = (4.0 / ViewingConditions.c) * math.sqrt(j / 100.0) * (ViewingConditions.aw + 4.0) * ViewingConditions.fl_root
        m = chroma * ViewingConditions.fl_root
        alpha = chroma / math.sqrt(j / 100.0) if j > 0 else 0
        s = 50.0 * math.sqrt((ViewingConditions.c * alpha) / (ViewingConditions.aw + 4.0))

        hue_radians = math.radians(hue)
        jstar = (1.0 + 100.0 * 0.007) * j / (1.0 + 0.007 * j)
        mstar = 1.0 / 0.0228 * math.log(1.0 + 0.0228 * m) if m > 0 else 0
        astar = mstar * math.cos(hue_radians)
        bstar = mstar * math.sin(hue_radians)

        return cls(hue, chroma, j, q, m, s, jstar, astar, bstar)

    def to_rgb(self) -> tuple[int, int, int]:
        """Convert CAM16 back to sRGB."""
        if self.chroma == 0 or self.j == 0:
            y = lstar_to_y(self.j)
            return xyz_to_rgb(y, y, y)

        hue_radians = math.radians(self.hue)

        alpha = self.chroma / math.sqrt(self.j / 100.0) if self.j > 0 else 0
        t = math.pow(alpha / math.pow(1.64 - math.pow(0.29, ViewingConditions.n), 0.73), 1.0 / 0.9)

        hue_prime = self.hue + 360.0 if self.hue < 20.14 else self.hue
        e_hue = 0.25 * (math.cos(math.radians(hue_prime) + 2.0) + 3.8)

        ac = ViewingConditions.aw * math.pow(self.j / 100.0, 1.0 / (ViewingConditions.c * ViewingConditions.z))
        p1 = 50000.0 / 13.0 * ViewingConditions.nc * ViewingConditions.ncb * e_hue
        p2 = ac / ViewingConditions.nbb

        gamma = 23.0 * (p2 + 0.305) * t / (23.0 * p1 + 11.0 * t * math.cos(hue_radians) + 108.0 * t * math.sin(hue_radians))

        a = gamma * math.cos(hue_radians)
        b = gamma * math.sin(hue_radians)

        r_a = (460.0 * p2 + 451.0 * a + 288.0 * b) / 1403.0
        g_a = (460.0 * p2 - 891.0 * a - 261.0 * b) / 1403.0
        b_a = (460.0 * p2 - 220.0 * a - 6300.0 * b) / 1403.0

        def reverse_adapt(adapted: float) -> float:
            abs_adapted = abs(adapted)
            base = max(0, 27.13 * abs_adapted / (400.0 - abs_adapted))
            return _signum(adapted) * 100.0 / ViewingConditions.fl * math.pow(base, 1.0 / 0.42)

        r_c = reverse_adapt(r_a) / ViewingConditions.RGB_D[0]
        g_c = reverse_adapt(g_a) / ViewingConditions.RGB_D[1]
        b_c = reverse_adapt(b_a) / ViewingConditions.RGB_D[2]

        x = 1.8620678 * r_c - 1.0112547 * g_c + 0.1491867 * b_c
        y = 0.3875265 * r_c + 0.6214474 * g_c - 0.0089739 * b_c
        z = -0.0158415 * r_c - 0.0344156 * g_c + 1.0502571 * b_c

        return xyz_to_rgb(x, y, z)


class Hct:
    """
    HCT (Hue, Chroma, Tone) color representation.

    Material Design 3's perceptual color space combining:
    - Hue: CAM16 hue (0-360)
    - Chroma: CAM16 chroma (colorfulness, typically 0-120+)
    - Tone: CIELAB L* lightness (0-100)
    """

    def __init__(self, hue: float, chroma: float, tone: float):
        self._hue = hue % 360.0
        self._chroma = max(0.0, chroma)
        self._tone = max(0.0, min(100.0, tone))
        self._argb: int | None = None

    @property
    def hue(self) -> float:
        return self._hue

    @property
    def chroma(self) -> float:
        return self._chroma

    @property
    def tone(self) -> float:
        return self._tone

    @classmethod
    def from_rgb(cls, r: int, g: int, b: int) -> 'Hct':
        """Create HCT from sRGB values."""
        cam = Cam16.from_rgb(r, g, b)
        _, y, _ = rgb_to_xyz(r, g, b)
        tone = y_to_lstar(y)
        return cls(cam.hue, cam.chroma, tone)

    @classmethod
    def from_argb(cls, argb: int) -> 'Hct':
        """Create HCT from ARGB integer."""
        r, g, b = int_to_rgb(argb)
        return cls.from_rgb(r, g, b)

    def to_rgb(self) -> tuple[int, int, int]:
        """Convert HCT to sRGB, solving for the color."""
        return self._solve_to_rgb(self._hue, self._chroma, self._tone)

    def to_argb(self) -> int:
        """Convert HCT to ARGB integer."""
        if self._argb is None:
            r, g, b = self.to_rgb()
            self._argb = argb_to_int(r, g, b)
        return self._argb

    def to_hex(self) -> str:
        """Convert HCT to hex string."""
        r, g, b = self.to_rgb()
        return f"#{r:02x}{g:02x}{b:02x}"

    @staticmethod
    def _solve_to_rgb(hue: float, chroma: float, tone: float) -> tuple[int, int, int]:
        """
        Solve for RGB given HCT values using the Material HctSolver.

        This uses proper gamut mapping that preserves hue exactly.
        When the requested chroma is out of gamut, it finds the maximum
        achievable chroma while maintaining the exact target hue.
        """
        return HctSolver.solve_to_rgb(hue, chroma, tone)

    def set_hue(self, hue: float) -> 'Hct':
        """Return new HCT with different hue."""
        return Hct(hue, self._chroma, self._tone)

    def set_chroma(self, chroma: float) -> 'Hct':
        """Return new HCT with different chroma."""
        return Hct(self._hue, chroma, self._tone)

    def set_tone(self, tone: float) -> 'Hct':
        """Return new HCT with different tone."""
        return Hct(self._hue, self._chroma, tone)


class TemperatureCache:
    """
    Color temperature analysis for finding harmonious colors.

    Based on Material Color Utilities - calculates relative warmth of colors
    and finds analogous colors based on temperature similarity.
    """

    def __init__(self, input_hct: Hct):
        self.input = input_hct
        self._hcts_by_temp: list[Hct] | None = None
        self._hcts_by_hue: list[Hct] | None = None
        self._temps_by_hct: dict[tuple[float, float, float], float] | None = None
        self._input_relative_temp: float | None = None
        self._complement: Hct | None = None

    @staticmethod
    def raw_temperature(hct: Hct) -> float:
        """
        Calculate raw temperature of a color using Ou-Woodcock-Wright algorithm.

        Based on material-colors Rust implementation.
        Uses LAB a* and b* to determine warm-cool factor.
        Values below 0 are cool, above 0 are warm.
        """
        # Convert HCT to RGB then to LAB
        rgb = hct.to_rgb()
        x, y, z = rgb_to_xyz(rgb[0], rgb[1], rgb[2])

        # XYZ to LAB
        def f(t: float) -> float:
            delta = 6.0 / 29.0
            if t > delta ** 3:
                return t ** (1.0 / 3.0)
            return t / (3 * delta * delta) + 4.0 / 29.0

        xn, yn, zn = 95.047, 100.0, 108.883  # D65 reference
        lab_a = 500.0 * (f(x / xn) - f(y / yn))
        lab_b = 200.0 * (f(y / yn) - f(z / zn))

        # Calculate LAB hue and chroma
        lab_hue = math.degrees(math.atan2(lab_b, lab_a))
        if lab_hue < 0:
            lab_hue += 360.0
        lab_chroma = math.hypot(lab_a, lab_b)

        # Ou-Woodcock-Wright formula for temperature
        # temp = -0.5 + 0.02 * chroma^1.07 * cos(toRadians(hue - 50))
        hue_rad = math.radians((lab_hue - 50.0) % 360.0)
        return -0.5 + 0.02 * (lab_chroma ** 1.07) * math.cos(hue_rad)

    def _get_hcts_by_hue(self) -> list[Hct]:
        """Generate HCT colors at regular hue intervals."""
        if self._hcts_by_hue is not None:
            return self._hcts_by_hue

        hcts = []
        for hue in range(360):
            color_at_hue = Hct(float(hue), self.input.chroma, self.input.tone)
            hcts.append(color_at_hue)

        self._hcts_by_hue = hcts
        return hcts

    def _get_temps_by_hct(self) -> dict[tuple[float, float, float], float]:
        """Cache temperatures for all hue variants."""
        if self._temps_by_hct is not None:
            return self._temps_by_hct

        hcts = self._get_hcts_by_hue()
        temps = {}
        for hct in hcts:
            key = (hct.hue, hct.chroma, hct.tone)
            temps[key] = self.raw_temperature(hct)

        self._temps_by_hct = temps
        return temps

    def _get_hcts_by_temp(self) -> list[Hct]:
        """Get HCT colors sorted by temperature."""
        if self._hcts_by_temp is not None:
            return self._hcts_by_temp

        hcts = list(self._get_hcts_by_hue())
        temps = self._get_temps_by_hct()
        hcts.sort(key=lambda h: temps[(h.hue, h.chroma, h.tone)])

        self._hcts_by_temp = hcts
        return hcts

    def _relative_temperature(self, hct: Hct) -> float:
        """
        Calculate relative temperature (0-1) based on position in temperature-sorted list.
        """
        temps = self._get_temps_by_hct()
        hcts_by_temp = self._get_hcts_by_temp()

        key = (hct.hue, hct.chroma, hct.tone)
        if key in temps:
            raw = temps[key]
        else:
            raw = self.raw_temperature(hct)

        # Find position in sorted list
        coldest = self.raw_temperature(hcts_by_temp[0])
        warmest = self.raw_temperature(hcts_by_temp[-1])

        if warmest == coldest:
            return 0.5

        return (raw - coldest) / (warmest - coldest)

    def _input_relative_temperature_value(self) -> float:
        """Get relative temperature of the input color."""
        if self._input_relative_temp is None:
            self._input_relative_temp = self._relative_temperature(self.input)
        return self._input_relative_temp

    def complement(self) -> Hct:
        """
        Find the complement: color with opposite temperature.
        """
        if self._complement is not None:
            return self._complement

        input_temp = self._input_relative_temperature_value()
        hcts_by_temp = self._get_hcts_by_temp()
        temps = self._get_temps_by_hct()

        # Target is opposite temperature
        target_temp = 1.0 - input_temp

        # Find closest match
        best_hct = hcts_by_temp[0]
        best_diff = float('inf')

        for hct in hcts_by_temp:
            key = (hct.hue, hct.chroma, hct.tone)
            raw = temps.get(key, self.raw_temperature(hct))
            rel = self._relative_temperature(hct)
            diff = abs(rel - target_temp)
            if diff < best_diff:
                best_diff = diff
                best_hct = hct

        self._complement = best_hct
        return best_hct

    def analogous(self, count: int | None = None, divisions: int | None = None) -> list[Hct]:
        """
        Find analogous colors based on temperature.

        Uses material-colors algorithm:
        1. Build a list of all `divisions` colors at equal temperature steps
        2. Pick `count` colors from this list, centered around the input

        Args:
            count: Number of colors to return (default 5)
            divisions: How many divisions of the temperature range (default 12)

        Returns:
            List of HCT colors including the input, spread by temperature.
        """
        if count is None:
            count = 5
        if divisions is None:
            divisions = 12

        hcts_by_hue = self._get_hcts_by_hue()
        start_hue = round(self.input.hue) % 360
        start_hct = hcts_by_hue[start_hue]

        # Calculate total absolute temperature delta around the color wheel
        last_temp = self._relative_temperature(start_hct)
        absolute_total_temp_delta = 0.0

        for i in range(360):
            hue = (start_hue + i) % 360
            hct = hcts_by_hue[hue]
            temp = self._relative_temperature(hct)
            temp_delta = abs(temp - last_temp)
            last_temp = temp
            absolute_total_temp_delta += temp_delta

        # Build list of all colors at equal temperature steps
        temp_step = absolute_total_temp_delta / divisions
        all_colors: list[Hct] = [start_hct]
        total_temp_delta = 0.0
        last_temp = self._relative_temperature(start_hct)
        hue_addend = 1

        while len(all_colors) < divisions and hue_addend <= 360:
            hue = (start_hue + hue_addend) % 360
            hct = hcts_by_hue[hue]
            temp = self._relative_temperature(hct)
            temp_delta = abs(temp - last_temp)
            total_temp_delta += temp_delta

            desired_total = len(all_colors) * temp_step

            # Add this hue until its temperature is insufficient
            while total_temp_delta >= desired_total and len(all_colors) < divisions:
                all_colors.append(hct)
                desired_total = (len(all_colors) + 1) * temp_step

            last_temp = temp
            hue_addend += 1

        # Fill remaining slots if needed
        while len(all_colors) < divisions:
            all_colors.append(all_colors[-1] if all_colors else start_hct)

        # Build final answer list centered around input
        answers: list[Hct] = [self.input]

        # Counter-clockwise (negative indices)
        increase_hue_count = int((count - 1) // 2)
        for i in range(1, increase_hue_count + 1):
            index = (-i) % len(all_colors)
            answers.insert(0, all_colors[index])

        # Clockwise (positive indices)
        decrease_hue_count = count - increase_hue_count - 1
        for i in range(1, decrease_hue_count + 1):
            index = i % len(all_colors)
            answers.append(all_colors[index])

        return answers


def fix_if_disliked(hct: Hct) -> Hct:
    """
    Fix colors in the "disliked" hue range (yellow-green).

    These colors often look muddy or unpleasant. If detected,
    shift the hue slightly to improve appearance.
    """
    # Disliked range: roughly 80-110 degrees (yellow-green)
    if hct.hue >= 80.0 and hct.hue <= 110.0 and hct.chroma > 16.0:
        # Shift towards warmer yellow or cooler green
        new_hue = 75.0 if hct.hue < 95.0 else 115.0
        return Hct(new_hue, hct.chroma, hct.tone)
    return hct


class TonalPalette:
    """
    A palette of tones for a single hue and chroma.

    Material Design 3 uses specific tone values for different UI elements.
    """

    def __init__(self, hue: float, chroma: float):
        self.hue = hue
        self.chroma = chroma
        self._cache: dict[int, int] = {}

    @classmethod
    def from_hct(cls, hct: Hct) -> 'TonalPalette':
        """Create TonalPalette from HCT color."""
        return cls(hct.hue, hct.chroma)

    @classmethod
    def from_rgb(cls, r: int, g: int, b: int) -> 'TonalPalette':
        """Create TonalPalette from RGB color."""
        hct = Hct.from_rgb(r, g, b)
        return cls(hct.hue, hct.chroma)

    def tone(self, t: int) -> int:
        """Get ARGB color at the specified tone (0-100)."""
        if t not in self._cache:
            hct = Hct(self.hue, self.chroma, float(t))
            self._cache[t] = hct.to_argb()
        return self._cache[t]

    def get_rgb(self, t: int) -> tuple[int, int, int]:
        """Get RGB color at the specified tone."""
        return int_to_rgb(self.tone(t))

    def get_hex(self, t: int) -> str:
        """Get hex color at the specified tone."""
        r, g, b = self.get_rgb(t)
        return f"#{r:02x}{g:02x}{b:02x}"
