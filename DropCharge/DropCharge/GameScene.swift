//
//  GameScene.swift
//  DropCharge
//
//  Created by Amy Joscelyn on 12/6/16.
//  Copyright © 2016 Amy Joscelyn. All rights reserved.
//

import SpriteKit

// MARK: – Game States
enum GameStatus: Int
{
    case waitingForTap = 0
    case waitingForBomb = 1
    case playing = 2
    case gameOver = 3
}

enum PlayerStatus: Int
{
    case idle = 0
    case jump = 1
    case fall = 2
    case lava = 3
    case dead = 4
}

class GameScene: SKScene
{
    // MARK: – Properties
    
    var bgNode: SKNode!
    var fgNode: SKNode!
    var backgroundOverlayTemplate: SKNode!
    var backgroundOverlayHeight: CGFloat!
    var player: SKSpriteNode!
    
    var platform5Across: SKSpriteNode!
    var coinArrow: SKSpriteNode!
    var lastOverlayPosition = CGPoint.zero
    var lastOverlayHeight: CGFloat = 0.0
    var levelPositionY: CGFloat = 0.0
    
    var gameState = GameStatus.waitingForTap
    var playerStatus = PlayerStatus.idle
    
    override func didMove(to view: SKView)
    {
        setupNodes()
        setupLevel()
        
        let scale = SKAction.scale(to: 1.0, duration: 0.5)
        fgNode.childNode(withName: "Ready")!.run(scale)
    }
    
    func setupNodes()
    {
        let worldNode = childNode(withName: "World")!
        bgNode = worldNode.childNode(withName: "Background")!
        backgroundOverlayTemplate = bgNode.childNode(withName: "Overlay")!.copy() as! SKNode
        backgroundOverlayHeight = backgroundOverlayTemplate.calculateAccumulatedFrame().height
        fgNode = worldNode.childNode(withName: "Foreground")!
        player = fgNode.childNode(withName: "Player") as! SKSpriteNode
        fgNode.childNode(withName: "Bomb")?.run(SKAction.hide())
        
        platform5Across = loadForegroundOverlayTemplate("Platform5Across")
        coinArrow = loadForegroundOverlayTemplate("CoinArrow")
    }
    
    func setupLevel()
    {
        // Place initial platform
        let initialPlatform = platform5Across.copy() as! SKSpriteNode
        var overlayPosition = player.position
        overlayPosition.y = player.position.y - ((player.size.height * 0.5) + (initialPlatform.size.height * 0.20))
        initialPlatform.position = overlayPosition
        fgNode.addChild(initialPlatform)
        lastOverlayPosition = overlayPosition
        lastOverlayHeight = initialPlatform.size.height / 2.0
        
        // Create random level
        levelPositionY = bgNode.childNode(withName: "Overlay")!.position.y + backgroundOverlayHeight
        while lastOverlayPosition.y < levelPositionY
        {
            addRandomForegroundOverlay()
        }
    }
    
    // MARK: – Overlay Nodes
    
    func loadForegroundOverlayTemplate(_ fileName: String) -> SKSpriteNode
    {
        let overlayScene = SKScene(fileNamed: fileName)
        let overlayTemplate = overlayScene?.childNode(withName: "Overlay")
        return overlayTemplate as! SKSpriteNode
    }
    
    func createForegroundOverlay(_ overlayTemplate: SKSpriteNode, flipX: Bool)
    {
        let foregroundOverlay = overlayTemplate.copy() as! SKSpriteNode
        lastOverlayPosition.y = lastOverlayPosition.y + (lastOverlayHeight + (foregroundOverlay.size.height / 2.0))
        lastOverlayHeight = foregroundOverlay.size.height / 2.0
        foregroundOverlay.position = lastOverlayPosition
        if flipX == true
        {
            foregroundOverlay.xScale = -1.0
        }
        fgNode.addChild(foregroundOverlay)
    }
    
    func addRandomForegroundOverlay()
    {
        let overlaySprite: SKSpriteNode!
        let platformPercentage = 60
        if Int.random(min: 1, max: 100) <= platformPercentage
        {
            overlaySprite = platform5Across
        }
        else
        {
            overlaySprite = coinArrow
        }
        createForegroundOverlay(overlaySprite, flipX: false)
    }
    
    func createBackgroundOverlay()
    {
        let backgroundOverlay = backgroundOverlayTemplate.copy() as! SKNode
        backgroundOverlay.position = CGPoint(x: 0.0, y: levelPositionY)
        bgNode.addChild(backgroundOverlay)
        levelPositionY += backgroundOverlayHeight
    }
    
    // MARK: – Events
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        if gameState == .waitingForTap
        {
            bombDrop()
        }
    }
    
    func bombDrop()
    {
        gameState = .waitingForBomb
        // Scale out title and ready lable
        let scale = SKAction.scale(to: 0, duration: 0.4)
        fgNode.childNode(withName: "Title")!.run(scale)
        fgNode.childNode(withName: "Ready")!.run(
            SKAction.sequence(
                [SKAction.wait(forDuration: 0.2),
                 scale]))
        
        // Bounce bomb
        let scaleUp = SKAction.scale(to: 1.25, duration: 0.25)
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.25)
        let sequence = SKAction.sequence([scaleUp, scaleDown])
        let repeatSeq = SKAction.repeatForever(sequence)
        fgNode.childNode(withName: "Bomb")!.run(SKAction.unhide())
        fgNode.childNode(withName: "Bomb")!.run(repeatSeq)
        run(SKAction.sequence(
            [SKAction.wait(forDuration: 2.0),
             SKAction.run(startGame)]))
    }
    
    func startGame()
    {
        fgNode.childNode(withName: "Bomb")!.removeFromParent()
        gameState = .playing
    }
}
