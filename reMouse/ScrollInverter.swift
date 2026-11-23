struct ScrollDeltas: Equatable {
    var axis1: Int64
    var axis2: Int64
    var point1: Int64
    var point2: Int64
    var fixed1: Double
    var fixed2: Double
}

func invertedDeltas(_ deltas: ScrollDeltas, isContinuous: Bool, enabled: Bool) -> ScrollDeltas {
    guard enabled, !isContinuous else { return deltas }
    return ScrollDeltas(
        axis1: 0 &- deltas.axis1,
        axis2: 0 &- deltas.axis2,
        point1: 0 &- deltas.point1,
        point2: 0 &- deltas.point2,
        fixed1: -deltas.fixed1,
        fixed2: -deltas.fixed2
    )
}
