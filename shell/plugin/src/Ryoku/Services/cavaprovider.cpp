#include "cavaprovider.hpp"

#include "audiocollector.hpp"
#include "audioprovider.hpp"

#ifdef RYOKU_HAS_CAVA
#include <cava/cavacore.h>
#endif

#include <algorithm>
#include <cstddef>
#include <qloggingcategory.h>

Q_LOGGING_CATEGORY(lcCava, "ryoku.services.cava", QtInfoMsg)
Q_LOGGING_CATEGORY(lcCavaProcessor, "ryoku.services.cava.processor", QtInfoMsg)

namespace ryoku::services {

#ifdef RYOKU_HAS_CAVA
CavaProcessor::CavaProcessor(QObject* parent)
    : AudioProcessor(parent)
    , m_plan(nullptr)
    , m_in(new double[ac::CHUNK_SIZE])
    , m_out(nullptr)
    , m_bars(0) {};

CavaProcessor::~CavaProcessor() {
    cleanup();
    delete[] m_in;
}

void CavaProcessor::process() {
    if (!m_plan || m_bars == 0 || !m_out) {
        return;
    }

    const int count = static_cast<int>(AudioCollector::instance().readChunk(m_in));

    // Process in data via cava
    cava_execute(m_in, count, m_out, m_plan);

    // Apply monstercat filter
    QVector<double> values(m_bars);

    // Left to right pass
    const double inv = 1.0 / 1.5;
    double carry = 0.0;
    for (int i = 0; i < m_bars; ++i) {
        carry = std::max(m_out[i], carry * inv);
        values[i] = carry;
    }

    // Right to left pass and combine
    carry = 0.0;
    for (int i = m_bars - 1; i >= 0; --i) {
        carry = std::max(m_out[i], carry * inv);
        values[i] = std::max(values[i], carry);
    }

    // Update values
    if (values != m_values) {
        m_values = std::move(values);
        emit valuesChanged(m_values);
    }
}

void CavaProcessor::setBars(int bars) {
    if (bars < 0) {
        qCWarning(lcCavaProcessor) << "setBars: bars must be greater than 0. Setting to 0.";
        bars = 0;
    }

    if (m_bars != bars) {
        m_bars = bars;
        reload();
    }
}

void CavaProcessor::setNoiseReduction(double noiseReduction) {
    noiseReduction = std::clamp(noiseReduction, 0.0, 1.0);
    if (!qFuzzyCompare(m_noiseReduction, noiseReduction)) {
        m_noiseReduction = noiseReduction;
        reload();
    }
}

void CavaProcessor::setAutoSens(bool autoSens) {
    if (m_autoSens != autoSens) {
        m_autoSens = autoSens;
        reload();
    }
}

void CavaProcessor::reload() {
    cleanup();
    initCava();
}

void CavaProcessor::cleanup() {
    if (m_plan) {
        cava_destroy(m_plan);
        m_plan = nullptr;
    }

    if (m_out) {
        delete[] m_out;
        m_out = nullptr;
    }
}

void CavaProcessor::initCava() {
    if (m_plan || m_bars == 0) {
        return;
    }

    m_plan = cava_init(m_bars, ac::SAMPLE_RATE, 1, m_autoSens ? 1 : 0, m_noiseReduction, 50, 10000);
    m_out = new double[static_cast<size_t>(m_bars)];
}
#endif

CavaProvider::CavaProvider(QObject* parent)
    : AudioProvider(parent)
    , m_bars(0)
    , m_values(m_bars, 0.0) {
#ifdef RYOKU_HAS_CAVA
    m_processor = new CavaProcessor();
    init();

    connect(static_cast<CavaProcessor*>(m_processor), &CavaProcessor::valuesChanged, this, &CavaProvider::updateValues);
#endif
}

int CavaProvider::bars() const {
    return m_bars;
}

void CavaProvider::setBars(int bars) {
    if (bars < 0) {
        qCWarning(lcCava) << "setBars: bars must be greater than 0. Setting to 0.";
        bars = 0;
    }

    if (m_bars == bars) {
        return;
    }

    m_values.resize(bars, 0.0);
    m_bars = bars;
    emit barsChanged();
    emit valuesChanged();

#ifdef RYOKU_HAS_CAVA
    QMetaObject::invokeMethod(
        static_cast<CavaProcessor*>(m_processor), &CavaProcessor::setBars, Qt::QueuedConnection, bars);
#endif
}

qreal CavaProvider::noiseReduction() const {
    return m_noiseReduction;
}

void CavaProvider::setNoiseReduction(qreal noiseReduction) {
    noiseReduction = std::clamp(noiseReduction, 0.0, 1.0);
    if (qFuzzyCompare(m_noiseReduction, noiseReduction)) {
        return;
    }

    m_noiseReduction = noiseReduction;
    emit noiseReductionChanged();

#ifdef RYOKU_HAS_CAVA
    QMetaObject::invokeMethod(
        static_cast<CavaProcessor*>(m_processor), &CavaProcessor::setNoiseReduction, Qt::QueuedConnection, noiseReduction);
#endif
}

bool CavaProvider::autoSens() const {
    return m_autoSens;
}

void CavaProvider::setAutoSens(bool autoSens) {
    if (m_autoSens == autoSens) {
        return;
    }

    m_autoSens = autoSens;
    emit autoSensChanged();

#ifdef RYOKU_HAS_CAVA
    QMetaObject::invokeMethod(
        static_cast<CavaProcessor*>(m_processor), &CavaProcessor::setAutoSens, Qt::QueuedConnection, autoSens);
#endif
}

QVector<double> CavaProvider::values() const {
    return m_values;
}

void CavaProvider::updateValues(QVector<double> values) {
    if (values != m_values) {
        m_values = values;
        emit valuesChanged();
    }
}

} // namespace ryoku::services
