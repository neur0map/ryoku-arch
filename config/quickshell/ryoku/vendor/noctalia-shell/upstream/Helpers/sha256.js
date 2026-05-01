function sha256(message) {
    // SHA-256 constants
    const K = [
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
    ];

    // Initial hash values
    let h0 = 0x6a09e667;
    let h1 = 0xbb67ae85;
    let h2 = 0x3c6ef372;
    let h3 = 0xa54ff53a;
    let h4 = 0x510e527f;
    let h5 = 0x9b05688c;
    let h6 = 0x1f83d9ab;
    let h7 = 0x5be0cd19;

    // Convert string to UTF-8 bytes manually
    const msgBytes = stringToUtf8Bytes(message);
    const msgLength = msgBytes.length;
    const bitLength = msgLength * 8;

    // Calculate padding
    // Message + 1 bit (0x80) + padding zeros + 8 bytes for length = multiple of 64 bytes
    const totalBitsNeeded = bitLength + 1 + 64; // message bits + padding bit + 64-bit length
    const totalBytesNeeded = Math.ceil(totalBitsNeeded / 8);
    const paddedLength = Math.ceil(totalBytesNeeded / 64) * 64; // Round up to multiple of 64
    
    const paddedMsg = new Array(paddedLength).fill(0);
    
    // Copy original message
    for (let i = 0; i < msgLength; i++) {
        paddedMsg[i] = msgBytes[i];
    }
    
    // Add padding bit (0x80 = 10000000 in binary)
    paddedMsg[msgLength] = 0x80;
    
    // Add length as 64-bit big-endian integer at the end
    // JavaScript numbers are not precise enough for 64-bit integers, so we handle high/low separately
    const highBits = Math.floor(bitLength / 0x100000000);
    const lowBits = bitLength % 0x100000000;
    
    // Write 64-bit length in big-endian format
    paddedMsg[paddedLength - 8] = (highBits >>> 24) & 0xFF;
    paddedMsg[paddedLength - 7] = (highBits >>> 16) & 0xFF;
    paddedMsg[paddedLength - 6] = (highBits >>> 8) & 0xFF;
    paddedMsg[paddedLength - 5] = highBits & 0xFF;
    paddedMsg[paddedLength - 4] = (lowBits >>> 24) & 0xFF;
    paddedMsg[paddedLength - 3] = (lowBits >>> 16) & 0xFF;
    paddedMsg[paddedLength - 2] = (lowBits >>> 8) & 0xFF;
    paddedMsg[paddedLength - 1] = lowBits & 0xFF;

    // Process message in 512-bit (64-byte) chunks
    for (let chunk = 0; chunk < paddedLength; chunk += 64) {
        const w = new Array(64);
        
        // Break chunk into sixteen 32-bit big-endian words
        for (let i = 0; i < 16; i++) {
            const offset = chunk + i * 4;
            w[i] = (paddedMsg[offset] << 24) |
                   (paddedMsg[offset + 1] << 16) |
                   (paddedMsg[offset + 2] << 8) |
                   paddedMsg[offset + 3];
            // Ensure unsigned 32-bit
            w[i] = w[i] >>> 0;
        }

        // Extend the sixteen 32-bit words into sixty-four 32-bit words
        for (let i = 16; i < 64; i++) {
            const s0 = rightRotate(w[i - 15], 7) ^ rightRotate(w[i - 15], 18) ^ (w[i - 15] >>> 3);
            const s1 = rightRotate(w[i - 2], 17) ^ rightRotate(w[i - 2], 19) ^ (w[i - 2] >>> 10);
            w[i] = (w[i - 16] + s0 + w[i - 7] + s1) >>> 0;
        }

        // Initialize working variables for this chunk
        let a = h0, b = h1, c = h2, d = h3, e = h4, f = h5, g = h6, h = h7;

        // Main loop
        for (let i = 0; i < 64; i++) {
            const S1 = rightRotate(e, 6) ^ rightRotate(e, 11) ^ rightRotate(e, 25);
            const ch = (e & f) ^ (~e & g);
            const temp1 = (h + S1 + ch + K[i] + w[i]) >>> 0;
            const S0 = rightRotate(a, 2) ^ rightRotate(a, 13) ^ rightRotate(a, 22);
            const maj = (a & b) ^ (a & c) ^ (b & c);
            const temp2 = (S0 + maj) >>> 0;

            h = g;
            g = f;
            f = e;
            e = (d + temp1) >>> 0;
            d = c;
            c = b;
            b = a;
            a = (temp1 + temp2) >>> 0;
        }

        // Add this chunk's hash to result so far
        h0 = (h0 + a) >>> 0;
        h1 = (h1 + b) >>> 0;
        h2 = (h2 + c) >>> 0;
        h3 = (h3 + d) >>> 0;
        h4 = (h4 + e) >>> 0;
        h5 = (h5 + f) >>> 0;
        h6 = (h6 + g) >>> 0;
        h7 = (h7 + h) >>> 0;
    }

    // Produce the final hash value as a hex string
    return [h0, h1, h2, h3, h4, h5, h6, h7]
        .map(h => h.toString(16).padStart(8, '0'))
        .join('');
}

function stringToUtf8Bytes(str) {
    const bytes = [];
    for (let i = 0; i < str.length; i++) {
        let code = str.charCodeAt(i);
        
        if (code < 0x80) {
            // 1-byte character (ASCII)
            bytes.push(code);
        } else if (code < 0x800) {
            // 2-byte character
            bytes.push(0xC0 | (code >> 6));
            bytes.push(0x80 | (code & 0x3F));
        } else if (code < 0xD800 || code > 0xDFFF) {
            // 3-byte character (not surrogate)
            bytes.push(0xE0 | (code >> 12));
            bytes.push(0x80 | ((code >> 6) & 0x3F));
            bytes.push(0x80 | (code & 0x3F));
        } else {
            // 4-byte character (surrogate pair)
            i++; // Move to next character
            const code2 = str.charCodeAt(i);
            const codePoint = 0x10000 + (((code & 0x3FF) << 10) | (code2 & 0x3FF));
            bytes.push(0xF0 | (codePoint >> 18));
            bytes.push(0x80 | ((codePoint >> 12) & 0x3F));
            bytes.push(0x80 | ((codePoint >> 6) & 0x3F));
            bytes.push(0x80 | (codePoint & 0x3F));
        }
    }
    return bytes;
}

function rightRotate(value, amount) {
    return ((value >>> amount) | (value << (32 - amount))) >>> 0;
}

// Test function to verify implementation
// function testSHA256() {
//   const tests = [
//     {
//       input: "",
//       expected:
//         "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
//     },
//     {
//       input: "Hello World",
//       expected:
//         "a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e",
//     },
//     {
//       input: "abc",
//       expected:
//         "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
//     },
//     {
//       input: "The quick brown fox jumps over the lazy dog",
//       expected:
//         "d7a8fbb307d7809469ca9abcb0082e4f8d5651e46d3cdb762d02d0bf37c9e592",
//     },
//   ];

//   console.log("Running SHA-256 tests:");
//   tests.forEach((test, i) => {
//     const result = Crypto.sha256(test.input);
//     const passed = result === test.expected;
//     console.log(`Test ${i + 1}: ${passed ? "PASS" : "FAIL"}`);
//     if (!passed) {
//       console.log(`  Input: "${test.input}"`);
//       console.log(`  Expected: ${test.expected}`);
//       console.log(`  Got:      ${result}`);
//     }
//   });
// }
