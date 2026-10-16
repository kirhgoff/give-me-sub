nonisolated struct CaptionTiming {
    var hideDelay = Duration.seconds(4)
    var flashDuration = Duration.seconds(1)
    var warningDuration = Duration.seconds(12)
    var cueTimePerWord = Duration.milliseconds(300)
    var cueMinimum = Duration.milliseconds(1500)
    var cueMaximum = Duration.milliseconds(3500)
    var cueIdleRelease = Duration.seconds(2)
    var cueMaximumDelay = Duration.milliseconds(3500)
}
