//
//  AudioManager.swift
//  Jumpcut
//
//  Created by Essam Salah on 18/01/2024.
//

import Foundation

import AVFAudio

class AudioManager {
  
  static let shared = AudioManager()
  private var player: AVAudioPlayer!
  
  var isSoundEffectEnabled: Bool = true
  
  private init() {
    if let file = Bundle.main.path(forResource: "pop", ofType: "wav") {
      let pathURL = URL(fileURLWithPath: file)
      do {
        try player = AVAudioPlayer(contentsOf: pathURL)
        player.prepareToPlay()
        player.volume = 0.1
      } catch {
        print(error)
      }
    }

  }
  
  func playClear() {
    
    if let file = Bundle.main.path(forResource: "clear", ofType: "wav") {
      let pathURL = URL(fileURLWithPath: file)
      
      do {
        try player = AVAudioPlayer(contentsOf: pathURL)
        
        play()
      } catch {
        print("error setting up audio session ")
      }
    }
  }
  
  func playPop() {
    
    if let file = Bundle.main.path(forResource: "pop", ofType: "wav") {
      let pathURL = URL(fileURLWithPath: file)
      
      do {
        try player = AVAudioPlayer(contentsOf: pathURL)
        play()
      } catch {
        print("error setting up audio session ")
      }
    }
  }
  
  
  func play() {
    if let isSoundEffectEnabled = UserDefaults.standard.value(forKey: SettingsPath.soundEffect.rawValue) as? Bool {
      self.isSoundEffectEnabled = isSoundEffectEnabled
    }
    if(isSoundEffectEnabled) {
      player.play()
    }
  }
  
}
