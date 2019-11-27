// Thanks to Sindre Sorhus for these utilities
// https://github.com/sindresorhus/do-not-disturb/blob/master/Sources/do-not-disturb/util.swift
import Cocoa

func sleep(for duration: TimeInterval) {
  usleep(useconds_t(duration * Double(USEC_PER_SEC)))
}
