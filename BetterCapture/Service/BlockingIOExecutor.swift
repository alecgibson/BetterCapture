//
//  BlockingIOExecutor.swift
//  BetterCapture
//

import Foundation

/// Runs its tasks one at a time on a serial queue of its own, outside Swift's shared thread pool,
/// for work that blocks the thread it runs on.
///
/// Swift's shared thread pool only has a thread per core, and `AVAssetReader` can't deliver a frame
/// while every one of them is blocked waiting for one, so enough blocking reads at once deadlock.
nonisolated final class BlockingIOExecutor: TaskExecutor {

    private let queue = DispatchQueue(label: "com.bettercapture.blockingIO")

    func enqueue(_ job: consuming ExecutorJob) {
        let job = UnownedJob(job)
        queue.async {
            job.runSynchronously(on: self.asUnownedTaskExecutor())
        }
    }
}
