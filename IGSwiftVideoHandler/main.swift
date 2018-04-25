//
//  main.swift
//  IGSwiftVideoHandler
//
//  Created by Isidoro Ghezzi on 15/04/15.
//  Copyright (c) 2015 Isidoro Ghezzi. All rights reserved.
//

import Foundation
import AVFoundation;

class IGHMS{
	let hour: Int64
	let minute: Int64
	let second: Float
	
	init (hour: Int64, minute: Int64, second: Float){
		self.hour = hour
		self.minute = minute
		self.second = second
	}
	
	func toTime () -> CMTime{
		let aValue: Int64 = (self.hour*3600 + self.minute * 60)*1000 + Int64 (self.second*1000)
		let ret: CMTime = CMTime (value: aValue, timescale: 1000, flags: CMTimeFlags.valid, epoch: CMTimeEpoch.allZeros)
		return ret
	}
	func toString () -> String{
		// return String(format:"%02.02d%02.02d%02.04f", self.hour, self.minute, self.second)
		return String(format:"%02d_%02d_%02.04f", self.hour, self.minute, self.second)
	}
}

class IGDDMMYYYY{
	let day: Int64
	let month: Int64
	let year: Int64
	
	init (day: Int64, month: Int64, year: Int64){
		self.day = day
		self.month = month
		self.year = year
	}
	
	func toString () -> String{
		return String(format:"%02.02d%02.02d%02.02d", self.day, self.month, self.year)
	}
}

class IGVideoHandler{
	fileprivate func getVisualFormatContraints () -> [AnyObject]{
		return ["H", "V"].map {
			return $0 + ":|-margin-[view]-margin-|"
		}
	}
	
	class fileprivate func toTime (_ hour: Int64, minute: Int64, second: Int64) -> CMTime{
		let aValue: Int64 = hour*3600 + minute * 60 + second
		let ret: CMTime = CMTime (value: aValue, timescale: 1, flags: CMTimeFlags.valid, epoch: CMTimeEpoch.allZeros)
		return ret
	}
	
	internal func doIt (){
		fatalError(#function + "Must be overridden");
	}
	
	internal func waitSemaphore (_ semaphore:DispatchSemaphore, exportSession:AVAssetExportSession){
		var aCycleCounter: Int64 = 0
		var aLastProgress: Float = 0
		while true {
			aCycleCounter += 1
			let aDispatchTime: DispatchTime = DispatchTime.now() + Double(1000*1000*1000*10) / Double(NSEC_PER_SEC)
			let aWaitResult = semaphore.wait(timeout: aDispatchTime)
			let aNow: Date = Date ()
			let aCurrentProgress: Float = exportSession.progress
			let aDeltaProgress: Float = aCurrentProgress - aLastProgress;
			print("\(aNow) - aCycleCounter: \(aCycleCounter); aWaitResult: \(aWaitResult); progress: \(aCurrentProgress); delta: \(aDeltaProgress)")
			aLastProgress = aCurrentProgress
			if 0 == aWaitResult{
				break;
			}
			//
		}
	}
}

class IGVideoMerger: IGVideoHandler {
	let fData:(sources:[(path:String, ext:String)], destination:String)
	init (theData:(sources:[(path:String, ext:String)], destination:String)){
		self.fData = theData;
	}
	override func doIt(){
		let aPathStringContainer: [(path: String, ext: String)] = self.fData.sources
		let mixComposition: AVMutableComposition = AVMutableComposition()
		let mutableCompVideoTrack:AVMutableCompositionTrack = mixComposition.addMutableTrack(withMediaType: AVMediaTypeVideo, preferredTrackID: Int32 (kCMPersistentTrackID_Invalid))
		let mutableCompAudioTrack:AVMutableCompositionTrack = mixComposition.addMutableTrack(withMediaType: AVMediaTypeAudio, preferredTrackID: Int32 (kCMPersistentTrackID_Invalid))
		
		var currentCMTime:CMTime = kCMTimeZero
		var i: Int = 0
		for aPath in aPathStringContainer{
			i += 1
			print ("aPath: \(aPath.path)");
			let videoFileData: Data = try! Data (contentsOf: URL(fileURLWithPath: aPath.path))
			let randomVideoFileURL: URL = URL (fileURLWithPath: "\(self.fData.destination)\(i).\(aPath.ext)")
			try? videoFileData.write (to: randomVideoFileURL, options: [.atomic])
			let videoAsset:AVAsset = AVAsset(url: randomVideoFileURL)
			let tracksKey: [String] = ["tracks"]
			var aDone: Bool = false
			
			let semaphore:DispatchSemaphore = DispatchSemaphore(value: 0)
			videoAsset.loadValuesAsynchronously(forKeys: tracksKey, completionHandler: { () -> Void in
				var error: NSError?
				let status: AVKeyValueStatus  = videoAsset.statusOfValue(forKey: tracksKey [0], error: &error)
				
				if status == AVKeyValueStatus.loaded {
					aDone = true
					// At this point you know the asset is ready
					if true == aDone{
						let aSignalResult = semaphore.signal()
						print("aSignalResult: \(aSignalResult)")
					}
				}
			})
			
			// self.waitSemaphore(semaphore, exportSession: videoAsset)
			var aCycleCounter: Int64 = 0
			while true {
				var error: NSError?
				let status: AVKeyValueStatus  = videoAsset.statusOfValue(forKey: tracksKey [0], error: &error)
				aCycleCounter += 1
				let aDispatchTime: DispatchTime = DispatchTime.now() + Double(1000*1000*1000*10) / Double(NSEC_PER_SEC)
				let aWaitResult = semaphore.wait(timeout: aDispatchTime)
				let aNow: Date = Date ()
				print("\(aNow) - aCycleCounter: \(aCycleCounter); aWaitResult: \(aWaitResult); status: \(status.rawValue)")
				if 0 == aWaitResult{
					break;
				}
			}
			
			var aVideo: [AnyObject] = videoAsset.tracks (withMediaType: AVMediaTypeVideo)
			var aAudio: [AnyObject] = videoAsset.tracks (withMediaType: AVMediaTypeAudio)
			if "mpeg" == aPath.ext {
				let instruction:AVMutableVideoCompositionInstruction = AVMutableVideoCompositionInstruction ()
				instruction.timeRange = CMTimeRangeMake(kCMTimeZero, videoAsset.duration)
				// instruction.set
				let transformer:AVMutableVideoCompositionLayerInstruction = AVMutableVideoCompositionLayerInstruction (assetTrack: aVideo [0] as! AVAssetTrack)
				let finalTransform:CGAffineTransform = CGAffineTransform ()
				transformer.setTransform(finalTransform, at:kCMTimeZero)
				transformer.setCropRectangle(CGRect(origin: CGPoint (x: 0, y: 0), size: CGSize (width: 960, height: 540)), at: kCMTimeZero)
			}
			else{
				do {
					try mutableCompVideoTrack.insertTimeRange (CMTimeRangeMake(kCMTimeZero, videoAsset.duration), of: aVideo [0] as! AVAssetTrack, at:currentCMTime)
				} catch _ {
				}
				do {
					try mutableCompAudioTrack.insertTimeRange (CMTimeRangeMake(kCMTimeZero, videoAsset.duration), of: aAudio[0] as! AVAssetTrack, at:currentCMTime)
				} catch _ {
				}
			}
			currentCMTime = CMTimeAdd(currentCMTime, videoAsset.duration);
		}
		
		let randomFinalVideoFileURL: URL = URL (fileURLWithPath: "\(self.fData.destination).mp4")
		let exportSession:AVAssetExportSession = AVAssetExportSession (asset: mixComposition, presetName: AVAssetExportPreset960x540)!
		exportSession.outputFileType = AVFileTypeMPEG4
		exportSession.outputURL = randomFinalVideoFileURL
		let val: CMTimeValue = mixComposition.duration.value
		let start: CMTime = CMTimeMake(0, 1)
		let duration: CMTime = CMTimeMake(val, 1)
		let range: CMTimeRange = CMTimeRangeMake(start, duration)
		exportSession.timeRange = range
		
		var aCounter: Int64 = 0
		var aDone: Bool = false
		let semaphore:DispatchSemaphore = DispatchSemaphore(value: 0)
		exportSession.exportAsynchronously(completionHandler: {
			aCounter += 1
			let aStatus: AVAssetExportSessionStatus = exportSession.status
			print ("aCounter: \(aCounter), status: \(aStatus.rawValue)")
			
			switch (aStatus){
			case AVAssetExportSessionStatus.completed:
				aDone = true
				break
			case AVAssetExportSessionStatus.waiting:
				break
			case AVAssetExportSessionStatus.exporting:
				break
			case AVAssetExportSessionStatus.failed:
				print("exportSession.error: \(exportSession.error)")
				aDone = true
				break
			case AVAssetExportSessionStatus.cancelled:
				print("exportSession.error: \(exportSession.error)")
				aDone = true
				break
			case AVAssetExportSessionStatus.unknown:
				break
			}
			if true == aDone{
				let aSignalResult = semaphore.signal()
				print("aSignalResult: \(aSignalResult)")
			}
			
		})
		self.waitSemaphore(semaphore, exportSession: exportSession)
	}
}

class IGVideoExtractor: IGVideoHandler {
	let fData:(source:String, title:String, date: IGDDMMYYYY, ranges:[(start: IGHMS, end: IGHMS)])
	init (theData:(source:String, title:String, date: IGDDMMYYYY, ranges:[(start: IGHMS, end: IGHMS)])){
		self.fData = theData;
	}
	override func doIt(){
		print(AVURLAsset.audiovisualTypes())
		
		let aURL: URL = URL (fileURLWithPath: self.fData.source)
		let aAsset: AVAsset = AVURLAsset (url: aURL, options: nil)
		print(aAsset)
		print(aAsset.trackGroups)
		print(aAsset.tracks)
		
		let movieTracks: [AnyObject] = aAsset.tracks (withMediaType: AVMediaTypeVideo);
		print(movieTracks)
		assert (1 == movieTracks.count);
		
		let compatiblePresets: [AnyObject] = AVAssetExportSession.exportPresets (compatibleWith: aAsset) as [AnyObject]
		print("compatiblePresets: \(compatiblePresets)")
		if (compatiblePresets as! [String]).contains(AVAssetExportPreset960x540){
			let queue:DispatchQueue = DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default);
			let group:DispatchGroup  = DispatchGroup();
			for aCurrentTimeRange in self.fData.ranges{
				queue.async(group: group,execute: {
					print ("start: \(aCurrentTimeRange.start.toString())")
					print ("end: \(aCurrentTimeRange.end.toString())")
					let exportSession: AVAssetExportSession = AVAssetExportSession (asset: aAsset, presetName: AVAssetExportPreset960x540)!
					exportSession.outputURL = URL (fileURLWithPath: String(format:"%@_%@_%@_%@.mp4", self.fData.title, self.fData.date.toString(), aCurrentTimeRange.start.toString(), aCurrentTimeRange.end.toString()))
					print ("exportSession.outputURL: \(exportSession.outputURL)");
					exportSession.outputFileType = AVFileTypeMPEG4
					
					let range: CMTimeRange = CMTimeRangeMake(aCurrentTimeRange.start.toTime(), CMTimeSubtract(aCurrentTimeRange.end.toTime(), aCurrentTimeRange.start.toTime()))
					exportSession.timeRange = range
					print ("range: \(range.duration.value)")
					print ("exportSession.estimatedOutputFileLength: \(exportSession.estimatedOutputFileLength)")
					var aCounter: Int64 = 0
					var aDone: Bool = false
					let semaphore:DispatchSemaphore = DispatchSemaphore(value: 0)
					exportSession.exportAsynchronously(completionHandler: {
						aCounter += 1
						let aStatus: AVAssetExportSessionStatus = exportSession.status
						print ("aCounter: \(aCounter), status: \(aStatus.rawValue)")
						
						switch (aStatus){
						case AVAssetExportSessionStatus.completed:
							aDone = true
							break
						case AVAssetExportSessionStatus.waiting:
							break
						case AVAssetExportSessionStatus.exporting:
							break
						case AVAssetExportSessionStatus.failed:
							print("exportSession.error: \(exportSession.error)")
							aDone = true
							break
						case AVAssetExportSessionStatus.cancelled:
							print("exportSession.error: \(exportSession.error)")
							aDone = true
							break
						case AVAssetExportSessionStatus.unknown:
							break
						}
						if true == aDone{
							let aSignalResult = semaphore.signal()
							print("aSignalResult: \(aSignalResult)")
						}
					})
					self.waitSemaphore(semaphore, exportSession: exportSession)
				})
			}
			group.wait(timeout: DispatchTime.distantFuture)
			// dispatch_release(group)
		}
	}
}

class IGVideoTester: IGVideoHandler {
	override func doIt(){
		let aPathStringContainer: [(path: String, ext: String)] = [
			(path:"test1", ext: "mpeg"),
			(path:"test2", ext: "mp4")
		]
		for aPath:(path: String, ext: String) in aPathStringContainer{
			let aVideoFileURL: URL = URL (fileURLWithPath: aPath.path)
			let videoAsset:AVAsset = AVAsset(url: aVideoFileURL)
			let seconds = CMTimeGetSeconds (videoAsset.duration)
			print("videoAsset.duration: \(seconds) s;")
		}
	}
}

func SwiftMainExtractor (){
	let aVideoHandler:IGVideoHandler = IGVideoExtractor (theData: (source: "test.mp4",
		title: "my_title",
		date:IGDDMMYYYY (day: 1, month: 7, year: 2016),
		ranges: [
			(start:IGHMS (hour:1, minute:50, second:59.75), end:IGHMS (hour:1, minute:51, second:56))
		]))
	aVideoHandler.doIt()
}

func SwiftMainMerger (){
	let aVideoHandler:IGVideoHandler = IGVideoMerger (theData: (sources:[(path: "file1", ext:"mpeg"), (path: "file2", ext:"mp4")], destination:"test"))
	aVideoHandler.doIt()
}

func SwiftMain (){
	SwiftMainMerger ();
}
SwiftMain ()
