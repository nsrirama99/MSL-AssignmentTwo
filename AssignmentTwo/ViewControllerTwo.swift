//
//  ViewControllerTwo.swift
//  AssignmentTwo
//
//  Created by UbiComp on 9/22/21.
//

import UIKit
import Metal

//global variables
let AUDIO_BUFFER_SIZE = Int(SAMPLING_RATE / 6) + 192
let SAMPLING_RATE = 48000


class ViewControllerTwo: UIViewController {

    @IBOutlet weak var FreqSlider: UISlider!
    @IBOutlet weak var GestureLabel: UILabel!
    
    @IBOutlet weak var freqLabel: UILabel!
    
    // setup audio model
    let audio = AudioModel(buffer_size: AUDIO_BUFFER_SIZE)
    
        lazy var graph:MetalGraph? = {
            return MetalGraph(mainView: self.view)
        }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //display graph with fftZoom
        graph?.addGraph(withName: "fft",
                        shouldNormalize: true,
                        numPointsInGraph: self.audio.fftZoom.count)
        
        
        freqLabel.text = "15000"
        GestureLabel.text = ""
        
        //run the processing to figure out hand movement to phone
        audio.startMicrophoneProcessingB(withFps: 10)
        audio.startProcessingSinewaveForPlayback(withFreq: 15000)
        
        audio.play();
        
        //start the graph output to base value
        self.audio.sineFrequency = 15000
        freqLabel.text = "Frequency: 15000"
        
        //create the index for value of slider
        let focusIndex = Int(Float(15000) / (Float(SAMPLING_RATE)/Float(AUDIO_BUFFER_SIZE)))

        self.audio.changeFocus(index: focusIndex)
        
        
        Timer.scheduledTimer(timeInterval: 0.05, target: self,
            selector: #selector(self.updateGraph),
            userInfo: nil,
            repeats: true)
       

        // Do any additional setup after loading the view.
    }
    
    //when the user leaves the view, we want to nil the audio processing blocks
       override func viewDidDisappear(_ animated: Bool) {
           super.viewDidDisappear(animated)
           audio.endAudioProcessing()
       }
    
    @IBAction func changeFrequency(_ sender: UISlider) {
        
        //sets the current sin wave frequency to the value of slider
        self.audio.sineFrequency = sender.value
        freqLabel.text = "Frequency: \(sender.value)"
        
        //create the index for value of slider
        let focusIndex = Int(Float(sender.value) / (Float(SAMPLING_RATE)/Float(AUDIO_BUFFER_SIZE)))

        self.audio.changeFocus(index: focusIndex)
    }
    
    @objc
    func updateGraph(){
        self.graph?.updateGraph(
            data: self.audio.fftZoom,
            forKey: "fft"
        )
        
        GestureLabel.text = audio.message

    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}

