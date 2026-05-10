import Testing
@testable import IThinkQ

struct ThinQRegionTests {
    @Test func mapsCountriesToRegions() {
        #expect(ThinQCountry.US.region == .aic)
        #expect(ThinQCountry.BR.region == .aic)
        #expect(ThinQCountry.KR.region == .kic)
        #expect(ThinQCountry.JP.region == .kic)
        #expect(ThinQCountry.DE.region == .eic)
    }
}
