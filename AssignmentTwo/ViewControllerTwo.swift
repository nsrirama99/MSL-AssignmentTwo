//
//  ViewControllerTwo.swift
//  AssignmentTwo
//
//  Created by UbiComp on 9/22/21.
//

import UIKit
import Metal

let AUDIO_BUFFER_SIZE = 1024*4


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
        
        graph?.addGraph(withName: "fft",
                        shouldNormalize: true,
                        numPointsInGraph: AUDIO_BUFFER_SIZE)
        
        
        audio.startMicrophoneProcessing(withFps: 10)
        
        audio.startProcessingSinewaveForPlayback(withFreq: 15)
        audio.play();
        
        
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
        self.audio.sineFrequency = sender.value
        freqLabel.text = "Frequency: \(sender.value)"
    }
    
    @objc
    func updateGraph(){
        self.graph?.updateGraph(
            data: self.audio.fftData,
            forKey: "fft"
        )
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
