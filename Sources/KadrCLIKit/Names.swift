import CoreMedia

/// Readable names for the codes and tags a container stores. Anything not listed
/// is reported as written, so an unfamiliar file still says what it is.
enum Names {

    static let videoCodec: [String: String] = [
        "avc1": "H.264",
        "avc3": "H.264",
        "hvc1": "HEVC",
        "hev1": "HEVC",
        "dvh1": "Dolby Vision (HEVC)",
        "dvhe": "Dolby Vision (HEVC)",
        "av01": "AV1",
        "vp09": "VP9",
        "apco": "ProRes 422 Proxy",
        "apcs": "ProRes 422 LT",
        "apcn": "ProRes 422",
        "apch": "ProRes 422 HQ",
        "ap4h": "ProRes 4444",
        "ap4x": "ProRes 4444 XQ",
        "aprn": "ProRes RAW",
        "aprh": "ProRes RAW HQ",
        "jpeg": "Motion JPEG",
        "mp4v": "MPEG-4 Part 2",
    ]

    static let audioCodec: [String: String] = [
        "aac ": "AAC",
        "aach": "HE-AAC",
        "aacp": "HE-AAC v2",
        "lpcm": "PCM",
        "alac": "Apple Lossless",
        "flac": "FLAC",
        "opus": "Opus",
        ".mp3": "MP3",
        "ac-3": "Dolby Digital",
        "ec-3": "Dolby Digital Plus",
        "apac": "APAC",
    ]

    static let primaries: [String: String] = [
        kCMFormatDescriptionColorPrimaries_ITU_R_709_2 as String: "BT.709",
        kCMFormatDescriptionColorPrimaries_ITU_R_2020 as String: "BT.2020",
        kCMFormatDescriptionColorPrimaries_P3_D65 as String: "Display P3",
        kCMFormatDescriptionColorPrimaries_DCI_P3 as String: "DCI-P3",
        kCMFormatDescriptionColorPrimaries_SMPTE_C as String: "SMPTE C",
        kCMFormatDescriptionColorPrimaries_EBU_3213 as String: "EBU 3213",
    ]

    static let transferFunction: [String: String] = [
        kCMFormatDescriptionTransferFunction_ITU_R_709_2 as String: "BT.709",
        kCMFormatDescriptionTransferFunction_ITU_R_2100_HLG as String: "HLG",
        kCMFormatDescriptionTransferFunction_SMPTE_ST_2084_PQ as String: "PQ",
        kCMFormatDescriptionTransferFunction_sRGB as String: "sRGB",
        kCMFormatDescriptionTransferFunction_Linear as String: "Linear",
        kCMFormatDescriptionTransferFunction_ITU_R_2020 as String: "BT.2020",
        kCMFormatDescriptionTransferFunction_SMPTE_240M_1995 as String: "SMPTE 240M",
    ]

    static let matrix: [String: String] = [
        kCMFormatDescriptionYCbCrMatrix_ITU_R_709_2 as String: "BT.709",
        kCMFormatDescriptionYCbCrMatrix_ITU_R_601_4 as String: "BT.601",
        kCMFormatDescriptionYCbCrMatrix_ITU_R_2020 as String: "BT.2020",
        kCMFormatDescriptionYCbCrMatrix_SMPTE_240M_1995 as String: "SMPTE 240M",
    ]
}
