//
//  ViewController.swift
//  AssignmentTwo
//
//  Created by UbiComp on 9/22/21.
//

import UIKit

class ViewController: UIViewController {
    
    //These 2 labels will be used to display the "current" max frequencies taken from the microphone
    @IBOutlet weak var Freq2Label: UILabel!
    @IBOutlet weak var Freq1Label: UILabel!
    
    var peaks:[Float:Float] = [:]
    lazy var peak1Frequency:Float = 0.0
    lazy var peak1Magnitude:Float = 0.0
    lazy var peak2Frequency:Float = 0.0
    lazy var peak2Magnitude:Float = 0.0
    
    //buffer size will determine accuracy of the fft
    //we want accuracy of 6Hz, 48100/6 = ~8017 buffer size needed
    //However we will also be interpolating frequencies, so we can get away with
    //a smaller buffer size, so we will use 1024*4 (power of 2 should be maintained)
    struct AudioConstants{
        static let AUDIO_BUFFER_SIZE = 1024*4
    }
    
    // setup audio model
    let audio = AudioModel(buffer_size: AudioConstants.AUDIO_BUFFER_SIZE)
    lazy var graph:MetalGraph? = {
        return MetalGraph(mainView: self.view)
    }()
    
    //On View Startup
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // add in graphs for display
        graph?.addGraph(withName: "fft",
                        shouldNormalize: true,
                        numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE/2)
        
        graph?.addGraph(withName: "time",
            shouldNormalize: false,
            numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE)
        
        // start up the audio model here, querying microphone
        audio.startMicrophoneProcessing(withFps: 10)
        audio.play()
        
        // run the loop for updating the graph peridocially
        Timer.scheduledTimer(timeInterval: 0.05, target: self,
            selector: #selector(self.update),
            userInfo: nil,
            repeats: true)
    }
    
    //when the user leaves the view, we want to nil the audio processing blocks
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        audio.endAudioProcessing()
    }

    // periodically, update the graph with refreshed FFT Data and update frequency peaks
    @objc
    func update(){
        self.graph?.updateGraph(
            data: self.audio.fftData,
            forKey: "fft"
        )
        
        self.graph?.updateGraph(
            data: self.audio.timeData,
            forKey: "time"
        )
        
        peaks = self.audio.fftPeaks
        
        let foundMax1 = peaks.max{a,b in a.value < b.value}
        peaks.removeValue(forKey: foundMax1!.key)
        let foundMax2 = peaks.max{a,b in a.value < b.value}
        
//        for (frequency, magnitude) in peaks {
//            if (magnitude > peak1Magnitude) {
//                peak2Magnitude = peak1Magnitude
//                peak2Frequency = peak2Frequency
//                peak1Magnitude = magnitude
//                peak1Frequency = frequency
//            }
//            else if (magnitude > peak2Magnitude) {
//                peak2Magnitude = magnitude
//                peak2Frequency = frequency
//            }
//        }
        
        if(!(self.audio.fftMean < -54.2 && self.audio.fftMean > -54.9)) {
            DispatchQueue.main.async {
                self.Freq1Label.text = foundMax1!.key.description
                self.Freq2Label.text = foundMax2!.key.description
            }
        }

    } //end update function

}

