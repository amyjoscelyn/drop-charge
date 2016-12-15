//
//  GameScene.swift
//  DropCharge
//
//  Created by Amy Joscelyn on 12/6/16.
//  Copyright © 2016 Amy Joscelyn. All rights reserved.
//

import SpriteKit
import CoreMotion

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

struct PhysicsCategory
{
    static let None: UInt32               = 0
    static let Player: UInt32             = 0b1      // 1
    static let PlatformNormal: UInt32     = 0b10     // 2
    static let PlatformBreakable: UInt32  = 0b100    // 4
    static let CoinNormal: UInt32         = 0b1000   // 8
    static let CoinSpecial: UInt32        = 0b10000  // 16
    static let Edges: UInt32              = 0b100000 // 32
}

class GameScene: SKScene, SKPhysicsContactDelegate
{
    // MARK: – Properties
    
    var bgNode: SKNode!
    var fgNode: SKNode!
    var backgroundOverlayTemplate: SKNode!
    var backgroundOverlayHeight: CGFloat!
    var player: SKSpriteNode!
    
    var platform5Across: SKSpriteNode!
    var platformArrow: SKSpriteNode!
    var platformDiagonal: SKSpriteNode!
    var break5Across: SKSpriteNode!
    var breakArrow: SKSpriteNode!
    var breakDiagonal: SKSpriteNode!
    var coin5Across: SKSpriteNode!
    var coinS5Across: SKSpriteNode!
    var coinArrow: SKSpriteNode!
    var coinSArrow: SKSpriteNode!
    var coinDiagonal: SKSpriteNode!
    var coinSDiagonal: SKSpriteNode!
    var coinCross: SKSpriteNode!
    var coinSCross: SKSpriteNode!
    
    var coin: SKSpriteNode!
    var coinSpecial: SKSpriteNode!
    
    var playerAnimationJump: SKAction!
    var playerAnimationFall: SKAction!
    var playerAnimationSteerLeft: SKAction!
    var playerAnimationSteerRight: SKAction!
    var currentPlayerAnimation: SKAction?
    
    var playerTrail: SKEmitterNode!
    
    let soundBombDrop = SKAction.playSoundFileNamed("bombDrop.wav", waitForCompletion: true)
    let soundSuperBoost = SKAction.playSoundFileNamed("nitro.wav", waitForCompletion: false)
    let soundTickTock = SKAction.playSoundFileNamed("tickTock.wav", waitForCompletion: true)
    let soundBoost = SKAction.playSoundFileNamed("boost.wav", waitForCompletion: false)
    let soundJump = SKAction.playSoundFileNamed("jump.wav", waitForCompletion: false)
    let soundCoin = SKAction.playSoundFileNamed("coin1.wav", waitForCompletion: false)
    let soundBrick = SKAction.playSoundFileNamed("brick.caf", waitForCompletion: false)
    let soundHitLava = SKAction.playSoundFileNamed("DrownFireBug.mp3", waitForCompletion: false)
    let soundGameOver = SKAction.playSoundFileNamed("player_die.wav", waitForCompletion: false)
    
    let soundExplosions = [
        SKAction.playSoundFileNamed("explosion1.wav", waitForCompletion: false),
        SKAction.playSoundFileNamed("explosion2.wav", waitForCompletion: false),
        SKAction.playSoundFileNamed("explosion3.wav", waitForCompletion: false),
        SKAction.playSoundFileNamed("explosion4.wav", waitForCompletion: false) ]
    
    var redAlertTime: TimeInterval = 0
    
    var lastOverlayPosition = CGPoint.zero
    var lastOverlayHeight: CGFloat = 0.0
    var levelPositionY: CGFloat = 0.0
    
    var gameState = GameStatus.waitingForTap
    var playerState = PlayerStatus.idle
    
    let motionManager = CMMotionManager()
    var xAcceleration = CGFloat(0)
    let cameraNode = SKCameraNode()
    
    var lava: SKSpriteNode!
    
    var lastUpdateTimeInterval: TimeInterval = 0
    var deltaTime: TimeInterval = 0
    
    var timeSinceLastExplosion: TimeInterval = 0
    var timeForNextExplosion: TimeInterval = 1.0
    
    var lives = 3
    
    let gameGain: CGFloat = 2.5
    
    override func didMove(to view: SKView)
    {
        setupNodes()
        setupLevel()
        
        let scale = SKAction.scale(to: 1.0, duration: 0.5)
        fgNode.childNode(withName: "Ready")!.run(scale)
        
        setupPlayer()
        setupCoreMotion()
        
        physicsWorld.contactDelegate = self
        
        camera?.position = CGPoint(x: size.width/2, y: size.height/2)
        
        playBackgroundMusic(name: "SpaceGame.caf")
        
        playerAnimationJump = setupAnimationWithPrefix(
            "player01_jump_", start: 1, end: 4, timePerFrame: 0.1)
        playerAnimationFall = setupAnimationWithPrefix(
            "player01_fall_", start: 1, end: 3, timePerFrame: 0.1)
        playerAnimationSteerLeft = setupAnimationWithPrefix(
            "player01_steerleft_", start: 1, end: 2, timePerFrame: 0.1)
        playerAnimationSteerRight = setupAnimationWithPrefix(
            "player01_steerright_", start: 1, end: 2, timePerFrame: 0.1)
    }
    
    // MARK: – Setup
    
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
        platformArrow = loadForegroundOverlayTemplate("PlatformArrow")
        platformDiagonal = loadForegroundOverlayTemplate("PlatformDiagonal")
        break5Across = loadForegroundOverlayTemplate("Break5Across")
        breakArrow = loadForegroundOverlayTemplate("BreakArrow")
        breakDiagonal = loadForegroundOverlayTemplate("BreakDiagonal")
        
        coin = loadCoin("Coin")
        coinSpecial = loadCoin("CoinSpecial")
        
        coin5Across = loadCoinOverlayTemplate("Coin5Across")
        coinS5Across = loadCoinOverlayTemplate("CoinS5Across")
        coinArrow = loadCoinOverlayTemplate("CoinArrow")
        coinSArrow = loadCoinOverlayTemplate("CoinSArrow")
        coinDiagonal = loadCoinOverlayTemplate("CoinDiagonal")
        coinSDiagonal = loadCoinOverlayTemplate("CoinSDiagonal")
        coinCross = loadCoinOverlayTemplate("CoinCross")
        coinSCross = loadCoinOverlayTemplate("CoinSCross")
        
        addChild(cameraNode)
        camera = cameraNode
        
        setupLava()
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
    
    func setupPlayer()
    {
        player.physicsBody = SKPhysicsBody(circleOfRadius: player.size.width * 0.3)
        player.physicsBody!.isDynamic = false
        player.physicsBody!.allowsRotation = false
        player.physicsBody!.categoryBitMask = PhysicsCategory.Player
        player.physicsBody!.collisionBitMask = 0
        
        playerTrail = addTrail(name: "PlayerTrail")
    }
    
    func setupCoreMotion()
    {
        motionManager.accelerometerUpdateInterval = 0.2
        let queue = OperationQueue()
        motionManager.startAccelerometerUpdates(to: queue, withHandler:
            { accelerometerData, error in
            guard let accelerometerData = accelerometerData else { return }
            let acceleration = accelerometerData.acceleration
            self.xAcceleration = (CGFloat(acceleration.x) * 0.75) + (self.xAcceleration * 0.25)
        })
    }
    
    func setupLava()
    {
        lava = fgNode.childNode(withName: "Lava") as! SKSpriteNode
        let emitter = SKEmitterNode(fileNamed: "Lava.sks")!
        emitter.particlePositionRange = CGVector(dx: size.width * 1.125, dy: 0.0)
        emitter.advanceSimulationTime(3.0)
        lava.addChild(emitter)
    }
    
    // MARK: – Overlay Nodes
    
    func loadCoin(_ fileName: String) -> SKSpriteNode
    {
        let coinScene = SKScene(fileNamed: fileName)!
        let coinTemplate = coinScene.childNode(withName: "Coin")
        return coinTemplate as! SKSpriteNode
    }
    
    func loadCoinOverlayTemplate(_ fileName: String) -> SKSpriteNode
    {
        let overlayTemplate = loadForegroundOverlayTemplate(fileName)
        
        overlayTemplate.enumerateChildNodes(withName: "*",
                                            using: { (node, stop) in
            let coinPos = node.position
            let coin: SKSpriteNode
            
            if node.name == "special"
            {
                coin = self.coinSpecial.copy() as! SKSpriteNode
            }
            else
            {
                coin = self.coin.copy() as! SKSpriteNode
            }
            
            coin.position = coinPos
            overlayTemplate.addChild(coin)
            node.removeFromParent()
        })
        return overlayTemplate
    }
    
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
        var flipH = false
        let platformPercentage = 60
        let regularPercentage = 75
        
        let regularPlatforms = [ platform5Across, platformArrow, platformDiagonal ]
        let breakablePlatforms = [ break5Across, breakArrow, breakDiagonal ]
        let regularCoins = [ coin5Across, coinArrow, coinDiagonal, coinCross ]
        let specialCoins = [ coinS5Across, coinSArrow, coinSDiagonal, coinSCross ]
        
        if Int.random(min: 1, max: 100) <= platformPercentage
        {
            if Int.random(min: 1, max: 100) <= regularPercentage
            {
                overlaySprite = regularPlatforms[Int.random(min: 1, max: regularPlatforms.count) - 1]
            }
            else
            {
                overlaySprite = breakablePlatforms[Int.random(min: 1, max: regularPlatforms.count) - 1]
            }
        }
        else
        {
            if Int.random(min: 1, max: 100) <= regularPercentage
            {
                overlaySprite = regularCoins[Int.random(min: 1, max: regularPlatforms.count) - 1]
            }
            else
            {
                overlaySprite = specialCoins[Int.random(min: 1, max: regularPlatforms.count) - 1]
            }
        }
        createForegroundOverlay(overlaySprite, flipX: flipH)
        
        /*
        let overlaySprite: SKSpriteNode!
        var flipH = false
        let platformPercentage = 60
        
        if Int.random(min: 1, max: 100) <= platformPercentage {
            if Int.random(min: 1, max: 100) <= 75 {
                // Create standard platforms 75%
                switch Int.random(min: 0, max: 3) {
                case 0:
                    overlaySprite = platformArrow
                case 1:
                    overlaySprite = platform5Across
                case 2:
                    overlaySprite = platformDiagonal
                case 3:
                    overlaySprite = platformDiagonal
                    flipH = true
                default:
                    overlaySprite = platformArrow
                }
            } else {
                // Create breakable platforms 25%
                switch Int.random(min: 0, max: 3) {
                case 0:
                    overlaySprite = breakArrow
                case 1:
                    overlaySprite = break5Across
                case 2:
                    overlaySprite = breakDiagonal
                case 3:
                    overlaySprite = breakDiagonal
                    flipH = true
                default:
                    overlaySprite = breakArrow
                }
            }
        } else {
            if Int.random(min: 1, max: 100) <= 75 {
                // Create standard coins 75%
                switch Int.random(min: 0, max: 4) {
                case 0:
                    overlaySprite = coinArrow
                case 1:
                    overlaySprite = coin5Across
                case 2:
                    overlaySprite = coinDiagonal
                case 3:
                    overlaySprite = coinDiagonal
                    flipH = true
                case 4:
                    overlaySprite = coinCross
                default:
                    overlaySprite = coinArrow
                }
            } else {
                // Create special coins 25%
                switch Int.random(min: 0, max: 4) {
                case 0:
                    overlaySprite = coinSArrow
                case 1:
                    overlaySprite = coinS5Across
                case 2:
                    overlaySprite = coinSDiagonal
                case 3:
                    overlaySprite = coinSDiagonal
                    flipH = true
                case 4:
                    overlaySprite = coinSCross
                default:
                    overlaySprite = coinSArrow
                }
            }
        }
        
        createForegroundOverlay(overlaySprite, flipX: flipH)
        */
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
        else if gameState == .gameOver
        {
            let newScene = GameScene(fileNamed: "GameScene")
            newScene!.scaleMode = .aspectFill
            let reveal = SKTransition.flipHorizontal(withDuration: 0.5)
            self.view?.presentScene(newScene!, transition: reveal)
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
            [soundBombDrop, soundTickTock,
             SKAction.run(startGame)]))
    }
    
    func startGame()
    {
        let bomb = fgNode.childNode(withName: "Bomb")!
        let bombBlast = explosion(intensity: 2.0)
        bombBlast.position = bomb.position
        fgNode.addChild(bombBlast)
        screenShakeByAmt(100)
        bomb.removeFromParent()
        run(soundExplosions[3])
        gameState = .playing
        player.physicsBody!.isDynamic = true
        superBoostPlayer()
        playBackgroundMusic(name: "bgMusic.mp3")
        
        let alarm = SKAudioNode(fileNamed: "alarm.wav")
        alarm.name = "alarm"
        alarm.autoplayLooped = true
        addChild(alarm)
    }
    
    func setPlayerVelocity(_ amount: CGFloat)
    {
        let gain: CGFloat = 2.5
        player.physicsBody!.velocity.dy = max(player.physicsBody!.velocity.dy, amount * gain)
    }
    
    func jumpPlayer()
    {
        setPlayerVelocity(650)
    }
    
    func boostPlayer()
    {
        setPlayerVelocity(1200)
        screenShakeByAmt(40)
    }
    
    func superBoostPlayer()
    {
        setPlayerVelocity(1700)
    }
    
    func didBegin(_ contact: SKPhysicsContact)
    {
        let other = contact.bodyA.categoryBitMask == PhysicsCategory.Player ? contact.bodyB : contact.bodyA
        
        switch other.categoryBitMask
        {
        case PhysicsCategory.CoinNormal:
            if let coin = other.node as? SKSpriteNode
            {
                emitParticles(name: "CollectNormal", sprite: coin)
                jumpPlayer()
                run(soundCoin)
            }
        case PhysicsCategory.CoinSpecial:
            if let coin = other.node as? SKSpriteNode
            {
                emitParticles(name: "CollectSpecial", sprite: coin)
                boostPlayer()
                run(soundBoost)
            }
        case PhysicsCategory.PlatformNormal:
            if let platform = other.node as? SKSpriteNode
            {
                if player.physicsBody!.velocity.dy < 0
                {
                    platformAction(platform, breakable: false)
                    jumpPlayer()
                    run(soundJump)
                }
            }
        case PhysicsCategory.PlatformBreakable:
            if let platform = other.node as? SKSpriteNode
            {
                if player.physicsBody!.velocity.dy < 0
                {
                    platformAction(platform, breakable: true)
                    jumpPlayer()
                    run(soundBrick)
                }
            }
        default:
            break
        }
    }
    
    //helper method
    func sceneCropAmount() -> CGFloat
    {
        guard let view = self.view else { return 0 }
        
        let scale = view.bounds.size.height / self.size.height
        let scaledWidth = self.size.width * scale
        let scaledOverlap = scaledWidth - view.bounds.size.width
        
        return scaledOverlap / scale
    }
    
    func gameOver()
    {
        gameState = .gameOver
        playerState = .dead
        
        physicsWorld.contactDelegate = nil
        player.physicsBody?.isDynamic = false
        
        let moveUp = SKAction.moveBy(x: 0.0,
                                     y: size.height / 2.0,
                                     duration: 0.5)
        moveUp.timingMode = .easeOut
        let moveDown = SKAction.moveBy(x: 0.0,
                                       y: -(size.height * 1.5),
                                       duration: 1.0)
        moveDown.timingMode = .easeIn
        player.run(SKAction.sequence([moveUp, moveDown]))
        run(soundGameOver)
        
        let gameOverSprite = SKSpriteNode(imageNamed: "GameOver")
        gameOverSprite.position = camera!.position
        gameOverSprite.zPosition = 10
        addChild(gameOverSprite)
        
        playBackgroundMusic(name: "SpaceGame.caf")
        if let alarm = childNode(withName: "alarm")
        {
            alarm.removeFromParent()
        }
        
        let blast = explosion(intensity: 3.0)
        blast.position = gameOverSprite.position
        blast.zPosition = 11
        addChild(blast)
        run(soundExplosions[3])
    }
    
    // MARK: – Updates
    
    func updatePlayer()
    {
        // Set velocity based on core motion
        player.physicsBody?.velocity.dx = xAcceleration * 1000.0
        
        // Wrap player around edges of screen
        var playerPosition = convert(player.position, from: fgNode)
        let leftLimit = sceneCropAmount()/2 - player.size.width/2
        let rightLimit = size.width - sceneCropAmount()/2 + player.size.width/2
        
        if playerPosition.x < leftLimit
        {
            playerPosition = convert(CGPoint(x: rightLimit, y: 0.0), to: fgNode)
            player.position.x = playerPosition.x
        }
        else if playerPosition.x > rightLimit
        {
            playerPosition = convert(CGPoint(x: leftLimit, y: 0.0), to: fgNode)
            player.position.x = playerPosition.x
        }
        
        // Check player state
        if player.physicsBody!.velocity.dy < CGFloat(0.0) && playerState != .fall
        {
            playerState = .fall
            if playerTrail.particleBirthRate == 0
            {
                playerTrail.particleBirthRate = 200
            }
        }
        else if player.physicsBody!.velocity.dy > CGFloat(0.0) && playerState != .jump
        {
            playerState = .jump
            print("Jumping.")
        }
        
        // Animate player
        if playerState == .jump
        {
            if abs(player.physicsBody!.velocity.dx) > 100.0
            {
                if player.physicsBody!.velocity.dx > 0
                {
                    runPlayerAnimation(playerAnimationSteerRight)
                }
                else
                {
                    runPlayerAnimation(playerAnimationSteerLeft)
                }
            }
            else
            {
                runPlayerAnimation(playerAnimationJump)
            }
        }
        else if playerState == .fall
        {
            runPlayerAnimation(playerAnimationFall)
        }
    }
    
    override func update(_ currentTime: TimeInterval)
    {
        if lastUpdateTimeInterval > 0
        {
            deltaTime = currentTime - lastUpdateTimeInterval
        }
        else
        {
            deltaTime = 0
        }
        lastUpdateTimeInterval = currentTime
        
        if isPaused
        {
            return
        }
        
        if gameState == .playing
        {
            updateCamera()
            updateLevel()
            updatePlayer()
            updateLava(deltaTime)
            updateCollisionLava()
            updateExplosions(deltaTime)
            updateRedAlert(deltaTime)
        }
    }
    
    func updateCamera()
    {
        let cameraTarget = convert(player.position, from: fgNode)
        var targetPositionY = cameraTarget.y - (size.height * 0.10)
        
        let lavaPos = convert(lava.position, from: fgNode)
        targetPositionY = max(targetPositionY, lavaPos.y)
        
        let diff = targetPositionY - camera!.position.y
        
        let cameraLagFactor = CGFloat(0.2)
        let lagDiff = diff * cameraLagFactor
        let newCameraPositionY = camera!.position.y + lagDiff
        
        camera?.position.y = newCameraPositionY
    }
    
    func updateLava(_ dt: TimeInterval)
    {
        let bottomOfScreenY = camera!.position.y - (size.height / 2)
        let bottomOfScreenYFg = convert(CGPoint(x: 0, y: bottomOfScreenY), to: fgNode).y
        
        let lavaVelocityY = CGFloat(120)
        let lavaStep = lavaVelocityY * CGFloat(dt)
        
        var newLavaPositionY = lava.position.y + lavaStep
        newLavaPositionY = max(newLavaPositionY, (bottomOfScreenYFg - 125.0))
        
        lava.position.y = newLavaPositionY
    }
    
    func updateCollisionLava()
    {
        if player.position.y < lava.position.y + 180
        {
            if playerState != .lava
            {
                playerState = .lava
                playerTrail.particleBirthRate = 0
                let smokeTrail = addTrail(name: "SmokeTrail")
                run(SKAction.sequence([
                    soundHitLava,
                    SKAction.wait(forDuration: 3.0),
                    SKAction.run() {
                        self.removeTrail(trail: smokeTrail)
                    }
                    ]))
            }
            boostPlayer()
            screenShakeByAmt(50)
            lives -= 1
            if lives <= 0
            {
                gameOver()
            }
        }
    }
    
    func updateExplosions(_ dt: TimeInterval)
    {
        timeSinceLastExplosion += dt
        if timeSinceLastExplosion > timeForNextExplosion
        {
            timeForNextExplosion = TimeInterval(CGFloat.random(min: 0.1, max: 0.5))
            timeSinceLastExplosion = 0
            
            createRandomExplosion()
        }
    }
    
    func updateRedAlert(_ lastUpdateTime: TimeInterval)
    {
        redAlertTime += lastUpdateTime
        let amt: CGFloat = CGFloat(redAlertTime) * π * 2.0 / 1.93725
        let colorBlendFactor = (sin(amt) + 1.0) / 2.0
        
        for bgChild in bgNode.children
        {
            for node in bgChild.children
            {
                if let sprite = node as? SKSpriteNode
                {
                    let nodePos = bgChild.convert(sprite.position, to: self)
                    
                    if !isNodeVisible(sprite, positionY: nodePos.y)
                    {
                        sprite.removeFromParent()
                    }
                    else
                    {
                        sprite.color = SKColorWithRGB(255, g: 0, b: 0)
                        sprite.colorBlendFactor = colorBlendFactor
                    }
                }
            }
            if bgChild.name == "Overlay" && bgChild.children.count == 0
            {
                bgChild.removeFromParent()
            }
        }
    }
    
    func updateLevel()
    {
        let cameraPos = camera!.position
        if cameraPos.y > levelPositionY - (size.height * 0.55)
        {
            createBackgroundOverlay()
            while lastOverlayPosition.y < levelPositionY
            {
                addRandomForegroundOverlay()
            }
        }
    }
    
    // MARK: – Particles
    
    func createRandomExplosion()
    {
        let cameraPos = camera!.position
        let sceneSize = self.size
        
        let explosionPos = CGPoint(x: CGFloat.random(min: 0.0, max: cameraPos.x * 2.0), y: CGFloat.random(min: cameraPos.y - sceneSize.height / 2, max: cameraPos.y + sceneSize.height * 0.35))
        
        let randomNum = Int.random(soundExplosions.count)
        run(soundExplosions[randomNum])
        
        let explode = explosion(intensity: 0.25 * CGFloat(randomNum + 1))
        explode.position = convert(explosionPos, to: bgNode)
        explode.run(SKAction.removeFromParentAfterDelay(2.0))
        bgNode.addChild(explode)
        
        if randomNum == 3
        {
            screenShakeByAmt(10)
        }
    }
    
    func explosion(intensity: CGFloat) -> SKEmitterNode
    {
        let emitter = SKEmitterNode()
        let particleTexture = SKTexture(imageNamed: "spark")
        
        emitter.zPosition = 2
        emitter.particleTexture = particleTexture
        emitter.particleBirthRate = 4000 * intensity
        emitter.numParticlesToEmit = Int(400 * intensity)
        emitter.particleLifetime = 2.0
        emitter.emissionAngle = CGFloat(90.0).degreesToRadians()
        emitter.emissionAngleRange = CGFloat(360.0).degreesToRadians()
        emitter.particleSpeed = 600 * intensity
        emitter.particleSpeedRange = 1000 * intensity
        emitter.particleAlpha = 1.0
        emitter.particleAlphaRange = 0.25
        emitter.particleScale = 1.2
        emitter.particleScaleRange = 2.0
        emitter.particleScaleSpeed = -1.5
        emitter.particleColorBlendFactor = 1
        emitter.particleBlendMode = SKBlendMode.add
        emitter.run(SKAction.removeFromParentAfterDelay(2.0))
        
        let sequence = SKKeyframeSequence(capacity: 5)
        sequence.addKeyframeValue(SKColor.white, time: 0)
        sequence.addKeyframeValue(SKColor.yellow, time: 0.10)
        sequence.addKeyframeValue(SKColor.orange, time: 0.15)
        sequence.addKeyframeValue(SKColor.red, time: 0.75)
        sequence.addKeyframeValue(SKColor.black, time: 0.95)
        emitter.particleColorSequence = sequence
        
        return emitter
    }
    
    func addTrail(name: String) -> SKEmitterNode
    {
        let trail = SKEmitterNode(fileNamed: name)!
        trail.zPosition = -1
        trail.targetNode = fgNode
        player.addChild(trail)
        return trail
    }
    
    func removeTrail(trail: SKEmitterNode)
    {
        trail.numParticlesToEmit = 1
        trail.run(SKAction.removeFromParentAfterDelay(1.0))
    }
    
    func playBackgroundMusic(name: String)
    {
        if let backgroundMusic = childNode(withName: "backgroundMusic")
        {
            backgroundMusic.removeFromParent()
        }
        
        let music = SKAudioNode(fileNamed: name)
        music.name = "backgroundMusic"
        music.autoplayLooped = true
        addChild(music)
    }
    
    func setupAnimationWithPrefix(_ prefix: String, start: Int, end: Int, timePerFrame: TimeInterval) -> SKAction
    {
        var textures = [SKTexture]()
        for i in start...end
        {
            textures.append(SKTexture(imageNamed: "\(prefix)\(i)"))
        }
        return SKAction.animate(with: textures, timePerFrame: timePerFrame)
    }
    
    func runPlayerAnimation(_ animation: SKAction)
    {
        if currentPlayerAnimation == nil || currentPlayerAnimation != animation
        {
            player.removeAction(forKey: "playerAnimation")
            player.run(animation, withKey: "playerAnimation")
            currentPlayerAnimation = animation
        }
    }
    
    func emitParticles(name: String, sprite: SKSpriteNode)
    {
        let pos = fgNode.convert(sprite.position, from: sprite.parent!)
        let particles = SKEmitterNode(fileNamed: name)!
        particles.position = pos
        particles.zPosition = 3
        fgNode.addChild(particles)
        particles.run(SKAction.removeFromParentAfterDelay(1.0))
        sprite.run(SKAction.sequence([
            SKAction.scale(to: 0.0, duration: 0.5),
            SKAction.removeFromParent()]))
    }
    
    func screenShakeByAmt(_ amt: CGFloat)
    {
        let worldNode = childNode(withName: "World")!
        worldNode.position = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
        worldNode.removeAction(forKey: "shake")
        
        let amount = CGPoint(x: 0, y: -(amt * gameGain))
        let action = SKAction.screenShakeWithNode(worldNode, amount: amount, oscillations: 10, duration: 2.0)
        
        worldNode.run(action, withKey: "shake")
    }
    
    func isNodeVisible(_ node: SKNode, positionY: CGFloat) -> Bool
    {
        if !camera!.contains(node)
        {
            if positionY < camera!.position.y - size.height * 2.0
            {
                return false
            }
        }
        return true
    }
    
    func platformAction(_ sprite: SKSpriteNode, breakable: Bool)
    {
        let amount = CGPoint(x: 0, y: -75.0)
        let action = SKAction.screenShakeWithNode(sprite, amount: amount, oscillations: 10, duration: 2.0)
        sprite.run(action)
        
        if breakable == true
        {
            emitParticles(name: "BrokenPlatform", sprite: sprite)
        }
    }
}
