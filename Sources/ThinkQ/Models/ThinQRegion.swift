import Foundation

enum ThinQRegion: String, CaseIterable, Identifiable, Sendable {
    case kic
    case aic
    case eic

    var id: String { rawValue }
}

enum ThinQCountry: String, CaseIterable, Identifiable, Sendable {
    case AE, AF, AG, AL, AM, AO, AR, AT, AU, AW, AZ, BA, BB, BD, BE, BF, BG, BH, BJ, BO, BR, BS, BY, BZ
    case CA, CD, CF, CG, CH, CI, CL, CM, CN, CO, CR, CU, CV, CY, CZ
    case DE, DJ, DK, DM, DO, DZ, EC, EE, EG, ES, ET, FI, FR
    case GA, GB, GD, GE, GH, GM, GN, GQ, GR, GT, GY
    case HK, HN, HR, HT, HU, Indonesia = "ID", IE, IL, IN, IQ, IR, IS, IT
    case JM, JO, JP, KE, KG, KH, KN, KR, KW, KZ, LA, LB, LC, LK, LR, LT, LU, LV, LY
    case MA, MD, ME, MK, ML, MM, MR, MT, MU, MW, MX, MY
    case NE, NG, NI, NL, NO, NP, NZ, OM, PA, PE, PH, PK, PL, PR, PS, PT, PY, QA
    case RO, RS, RU, RW, SA, SD, SE, SG, SI, SK, SL, SN, SO, SR, ST, SV, SY
    case TD, TG, TH, TN, TR, TT, TW, TZ, UA, UG, US, UY, UZ, VC, VE, VN, XK, YE, ZA, ZM

    var id: String { rawValue }

    var region: ThinQRegion {
        if Self.kicCountries.contains(self) { return .kic }
        if Self.aicCountries.contains(self) { return .aic }
        return .eic
    }

    private static let kicCountries: Set<ThinQCountry> = [.AU, .BD, .CN, .HK, .Indonesia, .IN, .JP, .KH, .KR, .LA, .LK, .MM, .MY, .NP, .NZ, .PH, .SG, .TH, .TW, .VN]
    private static let aicCountries: Set<ThinQCountry> = [.AG, .AR, .AW, .BB, .BO, .BR, .BS, .BZ, .CA, .CL, .CO, .CR, .CU, .DM, .DO, .EC, .GD, .GT, .GY, .HN, .HT, .JM, .KN, .LC, .MX, .NI, .PA, .PE, .PR, .PY, .SR, .SV, .TT, .US, .UY, .VC, .VE]
}
