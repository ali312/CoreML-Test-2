//
//  ViewController.swift
//  CoreMLTest2
//
//  Created by Anton Kuznetsov on 05.01.18.
//  Copyright © 2018 Anton Kuznetsov. All rights reserved.
//

import MobileCoreServices
import Vision
import CoreML
import AVKit

import UIKit

struct Objects {
    let objectArray = ["computer keyboard", "mouse", "iPod", "printer", "digital clock", "digital watch", "backpack", "ping-pong ball", "envelope", "water bottle", "combination lock", "lampshade", "switch", "lighter", "pillow", "spider web", "sandal", "vacuum", "wall clock", "bath towel", "wallet", "poster", "chocolate"]
}

class ViewController: UIViewController {
    @IBOutlet var scoreLabel: UILabel!
    @IBOutlet var highscoreLabel: UILabel!
    @IBOutlet var timeLabel: UILabel!
    @IBOutlet var objectLabel: UILabel!
    @IBOutlet var startButton: UIButton!
    @IBOutlet var skipButton: UIButton!
    @IBOutlet var topView: UIView!
    @IBOutlet var bottomView: UIView!
    
    var cameraLayer: CALayer!
    var gameTimer: Timer!
    var timeRemaining = 60
    var currentScore = 0
    var highScore = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        viewSetup()
        cameraSetup()
        getHighScore()
    }
    
    func viewSetup() {
        let backgroundColor = UIColor.init(white: 1, alpha: 0.8)
        topView.backgroundColor = backgroundColor
        bottomView.backgroundColor = backgroundColor
        scoreLabel.text = "0"
    }
    
    func cameraSetup() {
        let captureSession = AVCaptureSession()
        captureSession.sessionPreset = AVCaptureSession.Preset.photo
        let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)!
        let input = try! AVCaptureDeviceInput(device: backCamera)
        captureSession.addInput(input)
        
        cameraLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        view.layer.addSublayer(cameraLayer)
        cameraLayer.frame = view.bounds
        
        view.bringSubview(toFront: topView)
        view.bringSubview(toFront: bottomView)
        
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "buffer delegate"))
        videoOutput.recommendedVideoSettings(forVideoCodecType: .jpeg, assetWriterOutputFileType: .mp4)
        
        captureSession.addOutput(videoOutput)
        captureSession.sessionPreset = .high
        captureSession.startRunning()
    }
    
    func predict(image: CGImage) {
        let model = try! VNCoreMLModel(for: Inceptionv3().model)
        let request = VNCoreMLRequest(model: model, completionHandler: results)
        let handler = VNSequenceRequestHandler()
        try! handler.perform([request], on: image)
    }
    
    func results(request: VNRequest, error: Error?) {
        guard let results = request.results as? [VNClassificationObservation] else {
            print("No result found")
            return
        }
        
        guard results.count != 0 else {
            print("No result found")
            return
        }
        
        let highestConfidenceResult = results.first!
        let identifier = highestConfidenceResult.identifier.contains(", ") ? String(describing: highestConfidenceResult.identifier.split(separator: ",").first!) : highestConfidenceResult.identifier
        
        if identifier == objectLabel.text! {
            currentScore += 1
            //nextObject()
        }
    }
    
    func getHighScore() {
        if let score = UserDefaults.standard.object(forKey: "highscore") {
            highscoreLabel.text = "\(score)"
            highScore = score as! Int
        }
        else {
            print("No highscore, setting to 0.")
            highscoreLabel.text = "0"
            highScore = 0
            setHighScore(score: 0)
        }
    }
    
    func setHighScore(score: Int) {
        UserDefaults.standard.set(score, forKey: "highscore")
    }
    
    func endGame() {
        startButton.isHidden = false
        skipButton.isHidden = true
        objectLabel.text = "Game Over"
        
        if currentScore > highScore {
            setHighScore(score: currentScore)
            highscoreLabel.text = "\(currentScore)"
        }
        
        currentScore = 0
        timeRemaining = 60
        
    }
    
    func nextObject() {
        let allObjects = Objects().objectArray
        let randomObjectIndex = Int(arc4random_uniform(UInt32(allObjects.count)))
        
        guard allObjects[randomObjectIndex] != objectLabel.text else {
            nextObject()
            return
        }
        
        objectLabel.text = allObjects[randomObjectIndex]
        scoreLabel.text = "\(currentScore)"
    }
    
    @IBAction func startButtonTapped() {
        gameTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { (gameTimer) in
            guard self.timeRemaining != 0 else {
                gameTimer.invalidate()
                self.endGame()
                return
            }
            
            self.timeRemaining -= 1
            self.timeLabel.text = "\(self.timeRemaining)"
        })
        
        startButton.isHidden = true
        skipButton.isHidden = false
        nextObject()
        
    }
    
    @IBAction func skipButtonTapped() {
        nextObject()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { fatalError("pixel buffer is nil") }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: nil)
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { fatalError("cg image") }
        let uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .leftMirrored)
        
        DispatchQueue.main.sync {
            predict(image: uiImage.cgImage!)
        }
    }
}

