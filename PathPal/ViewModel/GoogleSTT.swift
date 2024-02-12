//
//  GoogleSTT.swift
//  PathPal
//
//  Created by Suji Lee on 2/8/24.
//

import Foundation
import googleapis
import AVFoundation
import SwiftUI

let HOST = "speech.googleapis.com"
let sttApiKey = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_STT_API_KEY") as? String ?? ""

class GoogleSpeechManager: ObservableObject {
    @Published var transcript = ""
    var prevTranscript = ""
    @Published var isFinal = false
    @Published var isRecording: Bool = false
    @Published var isRunningAudioSession: Bool = false
    
    var audioData: NSMutableData!
    let SAMPLE_RATE = 16000
    
    func startRecording() {
        isRecording = true
        isRunningAudioSession = true
        audioData = NSMutableData()
        _ = AudioController.sharedInstance.prepare(specifiedSampleRate: SAMPLE_RATE, processSampleDataCallback: processSampleData)
        SpeechRecognitionService.sharedInstance.sampleRate = SAMPLE_RATE
        _ = AudioController.sharedInstance.start()
    }
    
    func stopRecording() {
        _ = AudioController.sharedInstance.stop()
        SpeechRecognitionService.sharedInstance.stopStreaming()
        isRecording = false
        isRunningAudioSession = false
    }
    
    func getPrevTranscript() -> String {
        isFinal = false
        return prevTranscript
    }
    
    func processSampleData(_ data: Data) -> Void {
        audioData.append(data)
        
        // We recommend sending samples in 100ms chunks
        let chunkSize : Int /* bytes/chunk */ = Int(0.1 /* seconds/chunk */
                                                    * Double(SAMPLE_RATE) /* samples/second */
                                                    * 2 /* bytes/sample */);
        
        if (audioData.length > chunkSize) {
            SpeechRecognitionService.sharedInstance.streamAudioData(audioData,
                                                                    completion:
                                                                        { [weak self] (response, error) in
                guard let strongSelf = self else {
                    return
                }
                
                if let error = error {
                    strongSelf.transcript = error.localizedDescription
                } else if let response = response {
                    print(response)
                    if let result = response.resultsArray[0] as? StreamingRecognitionResult {
                        if let alternative = result.alternativesArray[0] as? SpeechRecognitionAlternative {
                            strongSelf.transcript = alternative.transcript
                            
                            if result.isFinal {
                                strongSelf.prevTranscript = strongSelf.transcript
                                strongSelf.transcript = ""
                                strongSelf.isFinal = true
                            }
                        }
                    }
                }
            })
            self.audioData = NSMutableData()
        }
    }
}

class AudioController {
    var remoteIOUnit: AudioComponentInstance? // optional to allow it to be an inout argument
    var processSampleDataCallback: ((Data) -> Void)!
    
    static var sharedInstance = AudioController()
    
    deinit {
        AudioComponentInstanceDispose(remoteIOUnit!);
    }
    
    func prepare(specifiedSampleRate: Int, processSampleDataCallback: @escaping (Data) -> Void) -> OSStatus {
        var status = noErr
        
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(AVAudioSession.Category.record)
            try session.setPreferredIOBufferDuration(10)
        } catch {
            return -1
        }
        
        var sampleRate = session.sampleRate
        print("hardware sample rate = \(sampleRate), using specified rate = \(specifiedSampleRate)")
        sampleRate = Double(specifiedSampleRate)
        
        self.processSampleDataCallback = processSampleDataCallback
        
        // Describe the RemoteIO unit
        var audioComponentDescription = AudioComponentDescription()
        audioComponentDescription.componentType = kAudioUnitType_Output;
        audioComponentDescription.componentSubType = kAudioUnitSubType_RemoteIO;
        audioComponentDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
        audioComponentDescription.componentFlags = 0;
        audioComponentDescription.componentFlagsMask = 0;
        
        // Get the RemoteIO unit
        let remoteIOComponent = AudioComponentFindNext(nil, &audioComponentDescription)
        status = AudioComponentInstanceNew(remoteIOComponent!, &remoteIOUnit)
        if (status != noErr) {
            return status
        }
        
        let bus1 : AudioUnitElement = 1
        var oneFlag : UInt32 = 1
        
        // Configure the RemoteIO unit for input
        status = AudioUnitSetProperty(remoteIOUnit!,
                                      kAudioOutputUnitProperty_EnableIO,
                                      kAudioUnitScope_Input,
                                      bus1,
                                      &oneFlag,
                                      UInt32(MemoryLayout<UInt32>.size));
        if (status != noErr) {
            return status
        }
        
        // Set format for mic input (bus 1) on RemoteIO's output scope
        var asbd = AudioStreamBasicDescription()
        asbd.mSampleRate = sampleRate
        asbd.mFormatID = kAudioFormatLinearPCM
        asbd.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked
        asbd.mBytesPerPacket = 2
        asbd.mFramesPerPacket = 1
        asbd.mBytesPerFrame = 2
        asbd.mChannelsPerFrame = 1
        asbd.mBitsPerChannel = 16
        status = AudioUnitSetProperty(remoteIOUnit!,
                                      kAudioUnitProperty_StreamFormat,
                                      kAudioUnitScope_Output,
                                      bus1,
                                      &asbd,
                                      UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
        if (status != noErr) {
            return status
        }
        
        // Set the recording callback
        var callbackStruct = AURenderCallbackStruct()
        callbackStruct.inputProc = recordingCallback
        callbackStruct.inputProcRefCon = nil
        status = AudioUnitSetProperty(remoteIOUnit!,
                                      kAudioOutputUnitProperty_SetInputCallback,
                                      kAudioUnitScope_Global,
                                      bus1,
                                      &callbackStruct,
                                      UInt32(MemoryLayout<AURenderCallbackStruct>.size));
        if (status != noErr) {
            return status
        }
        
        // Initialize the RemoteIO unit
        return AudioUnitInitialize(remoteIOUnit!)
    }
    
    func start() -> OSStatus {
        return AudioOutputUnitStart(remoteIOUnit!)
    }
    
    func stop() -> OSStatus {
        return AudioOutputUnitStop(remoteIOUnit!)
    }
}

// called through callbackStruct above
func recordingCallback(inRefCon:UnsafeMutableRawPointer,
                       ioActionFlags:UnsafeMutablePointer<AudioUnitRenderActionFlags>,
                       inTimeStamp:UnsafePointer<AudioTimeStamp>,
                       inBusNumber:UInt32,
                       inNumberFrames:UInt32,
                       ioData:UnsafeMutablePointer<AudioBufferList>?) -> OSStatus {
    
    var status = noErr
    
    let channelCount : UInt32 = 1
    
    var bufferList = AudioBufferList()
    bufferList.mNumberBuffers = channelCount
    let buffers = UnsafeMutableBufferPointer<AudioBuffer>(start: &bufferList.mBuffers,
                                                          count: Int(bufferList.mNumberBuffers))
    buffers[0].mNumberChannels = 1
    buffers[0].mDataByteSize = inNumberFrames * 2
    buffers[0].mData = nil
    
    // get the recorded samples
    status = AudioUnitRender(AudioController.sharedInstance.remoteIOUnit!,
                             ioActionFlags,
                             inTimeStamp,
                             inBusNumber,
                             inNumberFrames,
                             UnsafeMutablePointer<AudioBufferList>(&bufferList))
    if (status != noErr) {
        return status;
    }
    
    let data = Data(bytes:  buffers[0].mData!, count: Int(buffers[0].mDataByteSize))
    DispatchQueue.main.async {
        AudioController.sharedInstance.processSampleDataCallback(data)
    }
    
    return noErr
}

typealias SpeechRecognitionCompletionHandler = (StreamingRecognizeResponse?, NSError?) -> (Void)

class SpeechRecognitionService {
    var sampleRate: Int = 16000
    private var streaming = false
    
    private var client : Speech!
    private var writer : GRXBufferedPipe!
    private var call : GRPCProtoCall!
    
    static let sharedInstance = SpeechRecognitionService()
    
    func streamAudioData(_ audioData: NSData, completion: @escaping SpeechRecognitionCompletionHandler) {
        if (!streaming) {
            // if we aren't already streaming, set up a gRPC connection
            client = Speech(host:HOST)
            writer = GRXBufferedPipe()
            call = client.rpcToStreamingRecognize(withRequestsWriter: writer,
                                                  eventHandler:
                                                    { (done, response, error) in
                completion(response, error as? NSError)
            })
            // authenticate using an API key obtained from the Google Cloud Console
            call.requestHeaders.setObject(sttApiKey,
                                          forKey:NSString(string:"X-Goog-Api-Key"))
            print(sttApiKey)
            // if the API key has a bundle ID restriction, specify the bundle ID like this
            call.requestHeaders.setObject(NSString(string:Bundle.main.bundleIdentifier!),
                                          forKey:NSString(string:"X-Ios-Bundle-Identifier"))
            
            print("HEADERS:\(call.requestHeaders)")
            
            call.start()
            streaming = true
            
            // set up hints
            let speechContext = SpeechContext()
            speechContext.phrasesArray = ["jurisdiction", "extrapolate"]
            
            // send an initial request message to configure the service
            let recognitionConfig = RecognitionConfig()
            recognitionConfig.encoding =  .linear16
            recognitionConfig.sampleRateHertz = Int32(sampleRate)
//            recognitionConfig.languageCode = "en-US"
            recognitionConfig.languageCode = "ko-KR"
            recognitionConfig.maxAlternatives = 30
            recognitionConfig.enableWordTimeOffsets = true
            recognitionConfig.speechContextsArray = [speechContext]
            
            let streamingRecognitionConfig = StreamingRecognitionConfig()
            streamingRecognitionConfig.config = recognitionConfig
            streamingRecognitionConfig.singleUtterance = false
            streamingRecognitionConfig.interimResults = true
            
            let streamingRecognizeRequest = StreamingRecognizeRequest()
            streamingRecognizeRequest.streamingConfig = streamingRecognitionConfig
            
            writer.writeValue(streamingRecognizeRequest)
        }
        
        // send a request message containing the audio data
        let streamingRecognizeRequest = StreamingRecognizeRequest()
        streamingRecognizeRequest.audioContent = audioData as Data
        writer.writeValue(streamingRecognizeRequest)
    }
    
    func stopStreaming() {
        if (!streaming) {
            return
        }
        writer.finishWithError(nil)
        streaming = false
    }
    
    func isStreaming() -> Bool {
        return streaming
    }
}
