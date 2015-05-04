//
//  GameScene.swift
//  SpriteKitTutorial1
//
//  Created by André Helaehil on 04/05/15.
//  Copyright (c) 2015 André Helaehil. All rights reserved.
//

import SpriteKit
import AVFoundation

var backgroundMusicPlayer: AVAudioPlayer!

func playBackgroundMusic(filename: String) {
    let url = NSBundle.mainBundle().URLForResource(
        filename, withExtension: nil)
    if (url == nil) {
        println("Could not find file: \(filename)")
        return
    }
    
    var error: NSError? = nil
    backgroundMusicPlayer =
        AVAudioPlayer(contentsOfURL: url, error: &error)
    if backgroundMusicPlayer == nil {
        println("Could not create audio player: \(error!)")
        return
    }
    
    backgroundMusicPlayer.numberOfLoops = -1
    backgroundMusicPlayer.prepareToPlay()
    backgroundMusicPlayer.play()
}

struct PhysicsCategory {
    static let None: UInt32 = 0
    static let All: UInt32 = UInt32.max
    static let Monster: UInt32 = 0b1
    static let Projectile: UInt32 = 0b10
}

func + (left: CGPoint, right: CGPoint) -> CGPoint{
    return CGPoint(x: left.x + right.x, y: left.y + right.y)
}

func - (left: CGPoint, right: CGPoint) -> CGPoint{
    return CGPoint(x: left.x - right.x, y: left.y - right.y)
}

func * (point: CGPoint, scalar: CGFloat) -> CGPoint{
    return CGPoint(x: point.x * scalar, y: point.y * scalar)
}

func / (point: CGPoint, scalar: CGFloat) -> CGPoint{
    return CGPoint(x: point.x / scalar, y: point.y / scalar)
}

#if !(arch(x86_64) || arch(arm64))
    func sqrt(a: CGFloat) -> CGFloat {
    return CGFloat(sqrtf(Float(a)))
    }
#endif

extension CGPoint {
    func length() -> CGFloat {
        return sqrt(x*x + y*y)
    }
    
    func normalized() -> CGPoint {
        return self / length()
    }
}

class GameScene: SKScene, SKPhysicsContactDelegate {
    
    
    //Variável constante do player
    let player = SKSpriteNode(imageNamed: "player")
    var monstersDestroyed = 0
    
    override func didMoveToView(view: SKView) {
        playBackgroundMusic("Sounds/background-music-aac.caf")

        //Sem gravidade
        physicsWorld.gravity = CGVectorMake(0, 0)
        
        physicsWorld.contactDelegate = self
        
        //Setando cor do background
        backgroundColor = SKColor.whiteColor()
        //Posição do sprite 10% vertical e na metade horizontal
        player.position = CGPoint(x: size.width * 0.1, y: size.height * 0.5)
        //Fazer a sprite aparecer na cena, adicionando ele como uma criança.
        addChild(player)
        
        runAction(SKAction.repeatActionForever(
            SKAction.sequence([
                SKAction.runBlock(addMonster),
                SKAction.waitForDuration(1.0)
                ])
            ))
        
    }
   
    override func update(currentTime: CFTimeInterval) {
        /* Called before each frame is rendered */
    }
    
    func random() -> CGFloat{
        return CGFloat(Float(arc4random()) / 0xFFFFFFFF)
    }
    
    func random(#min: CGFloat, max: CGFloat) -> CGFloat{
        return random() * (max - min) + min
    }
    
    func addMonster(){
        
        //Cria o sprite
        let monster = SKSpriteNode(imageNamed: "monster")
        
        //Determina onde spawna o monstro pelo axis Y
        let actualY = random(min: monster.size.height/2, max: size.height - monster.size.height/2)
        
        //Posiciona o monstro um pouco fora da tela na beira da ponta direita e uma posição randômica pelo axis Y
        monster.position = CGPoint(x: size.width + monster.size.width/2, y: actualY)
        
        //Adiciona o monstro na cena
        addChild(monster)
        
        //Determina a velocidade do monstro
        let actualDuration = random(min: CGFloat(2.0), max: CGFloat(4.0))
        
        //Cria as ações
        let actionMove = SKAction.moveTo(CGPoint(x: -monster.size.width/2, y: actualY), duration: NSTimeInterval(actualDuration))
        let actionMoveDone = SKAction.removeFromParent()
        monster.runAction(SKAction.sequence([actionMove, actionMoveDone]))
        
        //Cria um physics body para o sprite definindo-o como um retângulo do mesmo tamanho.
        monster.physicsBody = SKPhysicsBody(rectangleOfSize: monster.size)
        
        //Seta sprite para ser dinâmico. Physics engine não controlarão o movimento do monstro.
        monster.physicsBody?.dynamic = true
        
        //Seta a categoria do bit mask para ser a categoria do monstro.
        monster.physicsBody?.categoryBitMask = PhysicsCategory.Monster
        
        //Indica qual categorias de objeto devem notificar quando há contato
        monster.physicsBody?.contactTestBitMask = PhysicsCategory.Projectile
        
        //Indica qual categorias de objeto o physic engine cuida de respostas de contato como bounce.
        monster.physicsBody?.collisionBitMask = PhysicsCategory.None
        
        let loseAction = SKAction.runBlock() {
            let reveal = SKTransition.flipHorizontalWithDuration(0.5)
            let gameOverScene = GameOverScene(size: self.size, won: false)
            self.view?.presentScene(gameOverScene, transition: reveal)
        }
        monster.runAction(SKAction.sequence([actionMove, loseAction, actionMoveDone]))
        
    }
    
    override func touchesEnded(touches: Set<NSObject>, withEvent event: UIEvent) {
        
        runAction(SKAction.playSoundFileNamed("Sounds/pew-pew-lei.caf", waitForCompletion: false))

        //Escolhe um dos toques para trabalhar com
        let touch = touches.first as! UITouch
        let touchLocation = touch.locationInNode(self)
        
        //Seta localização inicial do projétil
        let projectile = SKSpriteNode(imageNamed: "projectile")
        projectile.position = player.position
        
        projectile.physicsBody = SKPhysicsBody(circleOfRadius: projectile.size.width/2)
        projectile.physicsBody?.dynamic = true
        projectile.physicsBody?.categoryBitMask = PhysicsCategory.Projectile
        projectile.physicsBody?.contactTestBitMask = PhysicsCategory.Monster
        projectile.physicsBody?.collisionBitMask = PhysicsCategory.None
        projectile.physicsBody?.usesPreciseCollisionDetection = true
        
        //Determina "offset" da localização do projétil
        let offset = touchLocation - projectile.position
        
        //Para evitar que atire para trás
        if offset.x<0{
            return
        }
        
        addChild(projectile)
        
        //Pega a direção para onde atirar. Normalized() transforma o offset em um vetor de unidade.
        let direction = offset.normalized()
        
        //Fazer atirar bem longe para garantir que sairá da tela
        let shootAmount = direction*1000
        
        //Adiciona o "shootAmount"para a posição atual
        let realDest = shootAmount + projectile.position
        
        //Cria as ações
        let actionMove = SKAction.moveTo(realDest, duration: 2.0)
        let actionMoveDone = SKAction.removeFromParent()
        projectile.runAction(SKAction.sequence([actionMove, actionMoveDone]))
        
        
    }
    
    func projectileDidCollideWithMonster(projectile:SKSpriteNode, monster: SKSpriteNode){
        println("Hit")
        projectile.removeFromParent()
        monster.removeFromParent()
        monstersDestroyed++
        if (monstersDestroyed > 30) {
            let reveal = SKTransition.flipHorizontalWithDuration(0.5)
            let gameOverScene = GameOverScene(size: self.size, won: true)
            self.view?.presentScene(gameOverScene, transition: reveal)
        }
    }
    
    func didBeginContact(contact: SKPhysicsContact) {
        var firstBody: SKPhysicsBody
        var secondBody: SKPhysicsBody
        if contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask{
            firstBody = contact.bodyA
            secondBody = contact.bodyB
        }
        else{
            firstBody = contact.bodyB
            secondBody = contact.bodyA
        }
        
        if((firstBody.categoryBitMask & PhysicsCategory.Monster != 0) &&
            (secondBody.categoryBitMask & PhysicsCategory.Projectile != 0)){
                projectileDidCollideWithMonster(firstBody.node as! SKSpriteNode, monster: secondBody.node as! SKSpriteNode)
        }
    }
    
}
