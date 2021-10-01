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
    
    //buffer size will determine accuracy of the fft
    //we want accuracy of 6Hz, 48100/6 = ~8017 buffer size needed
    //However we will also be interpolating frequencies, so we can get away with
    //a smaller buffer size, so we will use 1024*4 (power of 2 should be maintained)
    struct AudioConstants{
        static let AUDIO_BUFFER_SIZE = 1024*8
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
        if((foundMax1) != nil) {
            peaks.removeValue(forKey: foundMax1!.key)
        }
        let foundMax2 = peaks.max{a,b in a.value < b.value}
        
        if let hopeItsNotNull = foundMax1 {
            if(hopeItsNotNull.value >= self.audio.fftMean+30) {
                DispatchQueue.main.async {
                    self.Freq1Label.text = foundMax1?.key.description
                    self.Freq2Label.text = foundMax2?.key.description
                }
            }
        }
        
//        if(foundMax1!.value >= 1.5*self.audio.fftMean) {
//            DispatchQueue.main.async {
//                self.Freq1Label.text = foundMax1?.key.description
//                self.Freq2Label.text = foundMax2?.key.description
//            }
//        }

    } //end update function

}

