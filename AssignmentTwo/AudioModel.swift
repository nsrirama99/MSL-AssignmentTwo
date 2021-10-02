//
//  AudioModel.swift
//  AudioLabSwift
//
//  Created by Eric Larson 
//  Copyright © 2020 Eric Larson. All rights reserved.
//

import Foundation
import Accelerate

class AudioModel {
    
    // immutable var for sampling rate
    var samplingRate = 48100
    
    // MARK: Properties
    private var BUFFER_SIZE:Int
    
    // Time 
    var timeData:[Float]
    var fftData:[Float]
    var fftZoom:[Float]
    
    // Holds the exponentially weighted moving average of frequency magnitudes
    var fftMean:Float
    
    // Dictionary to hold peak frequencies and magnitudes
    lazy var fftPeaks:[Float:Float] = [:]
    
    // variable which will hold the window size needed to find peaks at least 50Hz apart
    var windowSize:Int
    
    // variable containing frequency resolution of data
    var resolution:Float
    
    //variables to hold the windows for the selected freq and windows on either side
    var freqIndex: Int
    var freqPreIndex : Int
    var freqPostIndex: Int
    
    var message : String

    
    // MARK: Public Methods
    init(buffer_size:Int) {
        BUFFER_SIZE = buffer_size
        // anything not lazily instatntiated should be allocated here
        timeData = Array.init(repeating: 0.0, count: BUFFER_SIZE)
        fftData = Array.init(repeating: 0.0, count: BUFFER_SIZE/2)
        fftMean = -100.0 //Initialize moving average to -100 dB
        fftZoom = Array.init(repeating: 0.0, count: (101))
        
        
        freqIndex = 2560
        freqPreIndex = 0
        freqPostIndex = 0
        
        message = ""
        
        resolution = Float(samplingRate)/Float(BUFFER_SIZE)
        windowSize = 80/Int(resolution) // 80 Hz window
    }
    //public function for setting the index to whatever the input is
    func changeFocus(index:Int){
        //get values left and right of selected index
        freqIndex = index
        freqPreIndex = index - 50
        freqPostIndex = index + 50
    }

    // public function for starting processing of microphone data
    func startMicrophoneProcessing(withFps:Double){
        // setup the microphone to copy to circualr buffer
        if let manager = self.audioManager{
            manager.inputBlock = self.handleMicrophone
            
            // repeat this fps times per second using the timer class
            // every time this is called, we update the arrays "timeData",
            // "fftData"
            Timer.scheduledTimer(timeInterval: 1.0/withFps, target: self,
                                 selector: #selector(self.runEveryInterval),
                                 userInfo: nil,
                                 repeats: true)
        }
    }
    
    func startMicrophoneProcessingB(withFps:Double){
        // setup the microphone to copy to circualr buffer
        if let manager = self.audioManager{
            manager.inputBlock = self.handleMicrophone
            
            
            // repeat this fps times per second using the timer class
            // every time this is called, we update the arrays "timeData",
            // "fftData", and "fftLog"
            Timer.scheduledTimer(timeInterval: 1.0/withFps, target: self,
                                 selector: #selector(self.runEveryIntervalB),
                                 userInfo: nil,
                                 repeats: true)
        }
            
    }
    
    func startProcessingSinewaveForPlayback(withFreq:Float = 330.0){
        sineFrequency = withFreq
        self.audioManager?.setOutputBlockToPlaySineWave(sineFrequency)
    }
    
    
    // You must call this when you want the audio to start being handled by our model
    func play(){
        if let manager = self.audioManager{
            manager.play()
            samplingRate = Int(manager.samplingRate)
            resolution = Float(samplingRate)/Float(BUFFER_SIZE)
            windowSize = 60/Int(resolution)

            
            print(resolution.description + " " + windowSize.description)
        }
    }
    //public function to stop all audio processing
    func endAudioProcessing() {
        if let manager = self.audioManager{
            manager.pause()
            manager.inputBlock = nil
            manager.outputBlock = nil
        }
    }
    
    
    //==========================================
    // MARK: Private Properties
    private lazy var audioManager:Novocaine? = {
        return Novocaine.audioManager()
    }()
    
    private lazy var fftHelper:FFTHelper? = {
        return FFTHelper.init(fftSize: Int32(BUFFER_SIZE))
    }()
    
    
    private lazy var inputBuffer:CircularBuffer? = {
        return CircularBuffer.init(numChannels: Int64(self.audioManager!.numInputChannels),
                                   andBufferSize: Int64(BUFFER_SIZE))
    }()
    
    
    //==========================================
    // MARK: Private Methods
    // NONE for this model
    
    //==========================================
    // MARK: Model Callback Methods
    @objc private func runEveryInterval(){
        if inputBuffer != nil {
            // copy time data to swift array
            self.inputBuffer!.fetchFreshData(&timeData,
                                             withNumSamples: Int64(BUFFER_SIZE))
            
            // now take FFT
            fftHelper!.performForwardFFT(withData: &timeData,
                                         andCopydBMagnitudeToBuffer: &fftData)
            
            // at this point, we have saved the data to the arrays:
            //   timeData: the raw audio samples
            //   fftData:  the FFT of those same samples
            // the user can now use these variables however they like
            

            // Find peaks in frequency magnitues and perform quadratic interpolation
            fftPeaks.removeAll()
            for j in 0...(BUFFER_SIZE/2 - windowSize) {
                let end = j + windowSize
                let center = j + windowSize/2
                if (fftData[center] == fftData[j..<end].max()) {
                    let m1 = Float(fftData[center - 1])
                    let m2 = Float(fftData[center])
                    let m3 = Float(fftData[center + 1])
                    let approximation = (m1 - m3) / (m1 - 2 * m2 + m3) / 2
                    let fpeak = (Float(center) + approximation) * resolution
                    let mpeak = m2 - (m1 - m3) * approximation / 4
                    fftPeaks[fpeak] = mpeak
                }
            }
            
            // Update frequency magnitude moving average
            var temp:Float = 0.0
            vDSP_meanv(fftData, vDSP_Stride(1), &temp, vDSP_Length(fftData.count))
            fftMean += 0.2*(temp-fftMean)
        }
    }
    @objc private func runEveryIntervalB(){
        
        if(inputBuffer != nil){
        
        //gather data
        self.inputBuffer!.fetchFreshData(&timeData,
                                         withNumSamples: Int64(BUFFER_SIZE))
        
        // now take FFT
        fftHelper!.performForwardFFT(withData: &timeData,
                                     andCopydBMagnitudeToBuffer: &fftData)
            
            
        //Load only the selected view into new fftZoom
        var i = self.freqPreIndex
        var j = 0
        while i <= self.freqPostIndex {
            self.fftZoom[j] = self.fftData[i]
            j += 1
            i += 1
        }
    
        
        //find the peaks from either side of the array
        let preMax = self.fftZoom[30...45].max() ?? -1
        
        let postMax = self.fftZoom[60...79].max() ?? -1
        
        
            
        var fftPreDifference : Float
        var fftPostDifference : Float
            
        var threshhold :Float
        
      
        
        //calculate the percentages of difference from the peak to the max found
        fftPreDifference = abs(preMax - self.fftZoom[50] )
        
        fftPostDifference = abs(postMax - self.fftZoom[50])
        
        threshhold = fftPreDifference - fftPostDifference

        
        //output back to viewControllerTwo
        if(fftPostDifference > 41 && fftPreDifference > 32){
            message = ""
        }
        else if(threshhold > 0){
            message = "Towards"
        }
        else{
            message = "Away"
        }
    }
}
    //==========================================
    // MARK: Audiocard Callbacks
    // in obj-C it was (^InputBlock)(float *data, UInt32 numFrames, UInt32 numChannels)
    // and in swift this translates to:
    
    var sineFrequency:Float = 0.0{
        didSet{
            if let manager = self.audioManager{
                manager.sineFrequency = sineFrequency
            }
        }
    }
    private func handleMicrophone (data:Optional<UnsafeMutablePointer<Float>>, numFrames:UInt32, numChannels: UInt32) {
        // copy samples from the microphone into circular buffer
        self.inputBuffer?.addNewFloatData(data, withNumSamples: Int64(numFrames))
    }
    
    
}
