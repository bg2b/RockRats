//
//  BasicScene.swift
//  Asteroids
//
//  Created by David Long on 7/7/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit
import os.log

// MARK: zPositions

/// The main zPositions used in the app
enum LevelZs: CGFloat {
  case background = -200
  case stars = -100
  case playfield = 0
  case info = 100
  case pauseControls = 200
  case transition = 300
}

extension SKNode {
  /// Set the zPosition of a node
  /// - Parameter z: The desired Z
  func setZ(_ z: LevelZs) {
    zPosition = z.rawValue
  }
}

// MARK: - Physics body categories

/// Different types of objects, plus flags to indicate when something is off-screen
/// and when its coordinates have been wrapped by the playfield
enum ObjectCategories: UInt32 {
  // Basic categories
  case player =       0b00_00_00000001
  case playerShot =   0b00_00_00000010
  case ufo =          0b00_00_00000100
  case ufoShot =      0b00_00_00001000
  case fragment =     0b00_00_00010000
  case asteroid =     0b00_00_00100000
  // Two bits for asteroid size
  case hugeAsteroid = 0b00_11_00100000
  case bigAsteroid =  0b00_10_00100000
  case medAsteroid =  0b00_01_00100000
  // implicit case smAsteroid =   0b00_00_00100000
  // Additional flags
  case offScreen  =   0b01_00_00000000
  case hasWrapped =   0b10_00_00000000

  /// Is the category a basic type?
  var isBasic: Bool {
    let v = self.rawValue
    // Powers of two up through the asteroid type
    return v <= ObjectCategories.asteroid.rawValue && (v & (v - 1)) == 0
  }

  /// Is a category also some specified category?
  ///
  /// Note the asymmetry: `.asteroid.isA(.hugeAsteroid)`, but not vice versa
  func isA(_ category: ObjectCategories) -> Bool {
    return (rawValue & (category.rawValue)) == category.rawValue
  }
}

extension SKPhysicsBody {
  /// Is a physics body of a particular type?
  /// - Parameter category: The category
  /// - Returns: `true` if the body is of the type
  func isA(_ category: ObjectCategories) -> Bool {
    // Check equality rather than != 0 so that it works with types that have more
    // than one bit set.
    return (categoryBitMask & category.rawValue) == category.rawValue
  }

  /// Is a physics body one of some number of basic types?
  /// - Parameter categories: The types (use `setOf` to construct this from a list of categories)
  /// - Returns: `true` if the body is one of the types
  func isOneOf(_ categories: UInt32) -> Bool {
    return (categoryBitMask & categories) != 0
  }

  /// Is this body on the screen yet (and thus subject to coordinate wrapping)?
  var isOnScreen: Bool {
    get { return categoryBitMask & ObjectCategories.offScreen.rawValue == 0 }
    set { if newValue {
      categoryBitMask &= ~ObjectCategories.offScreen.rawValue
      } else {
      categoryBitMask |= ObjectCategories.offScreen.rawValue
      }
    }
  }

  /// Has the body wrapped from one side of the playfield to another?
  var hasWrapped: Bool {
    get { return categoryBitMask & ObjectCategories.hasWrapped.rawValue != 0 }
    set { if newValue {
      categoryBitMask |= ObjectCategories.hasWrapped.rawValue
    } else {
      categoryBitMask &= ~ObjectCategories.hasWrapped.rawValue
      }
    }
  }
}

/// This represents a combintion of object categories
/// - Parameter categories: A list of categories
/// - Returns: A bitmask representing the union of all the categories
func setOf(_ categories: [ObjectCategories]) -> UInt32 {
  return categories.reduce(0) { $0 | $1.rawValue }
}

// MARK: - Asteroid sizes

/// A convenience representation for asteroid sizes
enum AsteroidSize: Int {
  case small = 0
  case med = 1
  case big = 2
  case huge = 3

  /// Object category for asteroids of this size
  var category: ObjectCategories { ObjectCategories(rawValue: ObjectCategories.asteroid.rawValue | UInt32(sizeIndex << 8))! }

  /// What size asteroid does a physic body's category mask represent?
  /// - Parameter body: The physics body
  init?(ofBody body: SKPhysicsBody) {
    let asteroidsMask = setOf([ObjectCategories.hugeAsteroid, .bigAsteroid, .medAsteroid])
    switch body.categoryBitMask & asteroidsMask {
    case ObjectCategories.hugeAsteroid.rawValue: self = .huge
    case ObjectCategories.bigAsteroid.rawValue: self = .big
    case ObjectCategories.medAsteroid.rawValue: self = .med
    // Every other asteroid is small
    case ObjectCategories.asteroid.rawValue: self = .small
    // Nothing else is an asteroid
    default: return nil
    }
  }

  /// An alias for the size's raw value, 0 ... 3
  var sizeIndex: Int { rawValue }

  /// The string name for the size
  var sizeString: String {
    ["small", "med", "big", "huge"][sizeIndex]
  }

  /// The next smaller size
  var smaller: AsteroidSize { AsteroidSize(rawValue: sizeIndex - 1)! }
}

// MARK: - Random global stuff

extension Globals {
  /// `currentTime` of  last call to `update`
  static var lastUpdateTime = 0.0
  /// Cache of emitter nodes for splitting asteroids of various sizes; recycled
  /// repeatedly
  static var asteroidSplitEffectsCache = CyclicCache<AsteroidSize, SKEmitterNode>(cacheId: "Asteroid split effects cache")
}

// MARK: - Tiling shader

/// Create shader that will repeat a texture
///
/// The basic idea of the shader is to just take the texture coordinate, multiply
/// by the number of repetitions needed to cover the desired area both horizontally
/// and vertically, and then take the fractional parts as the coordinates to
/// actually look up in the texture.  Additional complications are because the
/// texture could be in an atlas and because I want to flip the repetitions around
/// a bit so that the tiling does not appear so uniform.
///
/// Using the shader to tile a node requires setting the `a_repetitions` attribute
/// to the desired repetition factor.  For example, if the screen is 1024x768 and
/// the texture is 256x256, `a_repetitons` would be (1024/256, 768/256) = (4, 3).
///
/// - Parameter texture: The texture to repeat
func tilingShader(forTexture texture: SKTexture) -> SKShader {
  // Do not to assume that the texture has v_tex_coord ranging in (0, 0) to (1, 1)!
  // If the texture is part of a texture atlas, this is not true.  Since I only use
  // this for a particular texture, I just pass in the texture and hard-code the
  // required v_tex_coord transformations.  For this case, the INPUT v_tex_coord is
  // from (0,0) to (1,1), since it corresponds to the coordinates in the shape node
  // that I'm tiling.  The OUTPUT v_tex_coord has to be in the space of the
  // texture, so it needs a scale and shift.
  //
  // (Actually I moved the background texture out of the texture atlas because
  // there seemed to be some weirdness that gave a slight green tinge to a border
  // in the latest Xcode for an iOS 12 device.  Since I'm tiling the whole
  // background anyway, having it not in the atlas won't affect the draw count.)
  let rect = texture.textureRect()
  let shaderSource = """
  void main() {
    vec2 scaled = v_tex_coord * a_repetitions;
    // rot is 0...3 and a repetion is rotated 90*rot degrees.  That
    // helps avoid any obvious patterning in this case.
    int rot = (int(scaled.x) + int(scaled.y)) & 0x3;
    v_tex_coord = fract(scaled);
    if (rot == 1) v_tex_coord = vec2(1.0 - v_tex_coord.y, v_tex_coord.x);
    else if (rot == 2) v_tex_coord = vec2(1.0) - v_tex_coord;
    else if (rot == 3) v_tex_coord = vec2(v_tex_coord.y, 1.0 - v_tex_coord.x);
    // Transform from (0,0)-(1,1)
    v_tex_coord *= vec2(\(rect.size.width), \(rect.size.height));
    v_tex_coord += vec2(\(rect.origin.x), \(rect.origin.y));
    gl_FragColor = SKDefaultShading();
  }
  """
  let shader = SKShader(source: shaderSource)
  shader.attributes = [SKAttribute(name: "a_repetitions", type: .vectorFloat2)]
  return shader
}

// MARK: - Transition shader

/// Make a shader for scene transitions
///
/// This is a circular mask that shrinks/grows to hide or reveal the scene.
///
/// - Parameters:
///   - isEntering: `true` for the new (incoming) scene, `false` for the old (outgoing) one
///   - duration: The time for the effect
func enterExitShader(isEntering: Bool, duration: Double) -> SKShader {
  let rgba = AppAppearance.transitionColor.cgColor.components!
  let shaderSource = """
  void main() {
    // Time goes 0-1
    float dt = min(a_time / \(duration), 1.0);
    // Size goes 0-1 for entering, and 1-0 for exiting
    float size = \(isEntering ? "" : "1.0 - ")dt;
    // Compute normalized distance from center
    float p = distance(v_tex_coord, vec2(0.5, 0.5)) / 0.708;  // 1/sqrt(2)+eps
    if (p > size) {
      // Outside gets clipped
      gl_FragColor = vec4(\(rgba[0]), \(rgba[1]), \(rgba[2]), 1.0);
    } else {
      gl_FragColor = vec4(0.0);
    }
  }
  """
  let shader = SKShader(source: shaderSource)
  shader.attributes = [SKAttribute(name: "a_time", type: .float)]
  return shader
}

// MARK: - Base class for all scenes

/// The root class of all the scenes in the game
///
/// Provides a playing area, audio, a set of asteroids, and a set of UFOs.  The
/// class's methods deal with those objects, plus common stuff like scene pauses,
/// follow-on scene creation, and scene transitions.
class BasicScene: SKScene, SKPhysicsContactDelegate {
  /// The full screen with (0, 0) at the center
  var fullFrame: CGRect!
  /// The frame for game action (may be less than `fullFrame` due to safe area
  /// exclusion)
  var gameFrame: CGRect!
  /// Crops to exlude safe area if fullFrame != gameFrame
  var gameAreaCrop = SKCropNode()
  /// Home for all the game elements (asteroids, UFOs, ships, info, etc.).  This is
  /// an effect node so that a filter can be applied to all of those elements (e.g.,
  /// blurring them when the game is paused).  But see discussion under
  /// `setGameAreaBlur`.
  var gameArea = SKEffectNode()
  /// When the game is paused, this is set to a blurred image
  var pausedEffect: SKSpriteNode?
  /// The playfield holds the non-info stuff (asteroid, ships, etc.), i.e., things
  /// that move around and undergo coordinate wrapping.
  var playfield: Playfield!
  /// This handles all the sounds of the scene
  var audio: SceneAudio!
  /// All the asteroids (some may be off-screen still)
  var asteroids = Set<SKSpriteNode>()
  /// When `false`, getting an asteroid with the Little Prince is not allowed
  var littlePrinceAllowed = true
  /// All the UFOs (some may be off-screen still)
  var ufos = Set<UFO>()
  /// Becomes `true` when getting ready to switch scenes; see `beginSceneSwitch`
  /// discussion.
  var switchingScenes = false
  /// A transition node that masks the scene until it starts running
  var entryTransition: SKSpriteNode?
  /// Signpost ID for this instance
  let signpostID = OSSignpostID(log: .poi)

  // MARK: - Initialization

  /// Background texture
  static let backgroundTexture = Globals.textureCache.findTexture(imageNamed: "starfield_blue")
  /// Background shader
  static let backgroundShader = tilingShader(forTexture: backgroundTexture)

  /// Make the background of the entire game
  ///
  /// I use a single background tile and repeat that over the whole screen with
  /// various flips so that it looks not very uniform.
  func initBackground() {
    let stars = BasicScene.backgroundTexture
    let background = SKSpriteNode(texture: stars, size: gameFrame.size)
    background.name = "background"
    background.setZ(.background)
    let tsize = stars.size()
    background.shader = BasicScene.backgroundShader
    let reps = vector_float2([Float(gameFrame.width / tsize.width), Float(gameFrame.height / tsize.height)])
    background.setValue(SKAttributeValue(vectorFloat2: reps), forAttribute: "a_repetitions")
    gameArea.addChild(background)
  }

  /// Create a twinkle action for stars
  /// - Parameters:
  ///   - period: The period of repeats (different stars run the action at different speeds though)
  ///   - dim: How dim to be most of time
  ///   - bright: How bright to get during the twinkle
  func twinkleAction(period: Double, from dim: CGFloat, to bright: CGFloat) -> SKAction {
    let twinkleDuration = 0.4
    let brighten = SKAction.fadeAlpha(to: bright, duration: 0.5 * twinkleDuration)
    brighten.timingMode = .easeIn
    let fade = SKAction.fadeAlpha(to: dim, duration: 0.5 * twinkleDuration)
    fade.timingMode = .easeOut
    return SKAction.repeatForever(.sequence([brighten, fade, .wait(forDuration: period - twinkleDuration)]))
  }

  /// Make an individual star
  ///
  /// The colors are from an RGB table I found on an astronomy site for stars of
  /// different temperatures.
  func makeStar() -> SKSpriteNode {
    let tints = [RGB(202, 215, 255),
                 RGB(248, 247, 255),
                 RGB(255, 244, 234),
                 RGB(255, 210, 161),
                 RGB(255, 204, 111)]
    let tint = tints.randomElement()!
    let texture = Globals.textureCache.findTexture(imageNamed: "star1")
    let star = SKSpriteNode(texture: texture, size: texture.size().scale(by: .random(in: 0.5 ... 1.0)))
    star.name = "star"
    star.color = tint
    star.colorBlendFactor = 1.0
    return star
  }

  /// Make a bunch of background stars that twinkle
  func initStars() {
    let stars = SKNode()
    stars.name = "stars"
    stars.setZ(.stars)
    gameArea.addChild(stars)
    let dim = CGFloat(0.1)
    let bright = CGFloat(0.3)
    let period = 8.0
    let twinkle = twinkleAction(period: period, from: dim, to: bright)
    for _ in 0 ..< 100 {
      let star = makeStar()
      star.alpha = dim
      var minSep = CGFloat(0)
      let wantedSep = 3 * star.size.diagonal()
      while minSep < wantedSep {
        minSep = .infinity
        star.position = CGPoint(x: .random(in: gameFrame.minX ... gameFrame.maxX),
                                y: .random(in: gameFrame.minY ... gameFrame.maxY))
        for otherStar in stars.children {
          minSep = min(minSep, (otherStar.position - star.position).length())
        }
      }
      star.wait(for: .random(in: 0.0 ... period), then: twinkle)
      star.speed = .random(in: 0.75 ... 1.5)
      stars.addChild(star)
    }
  }

  /// Make the playfield that will hold asteroids, UFOs, the player, etc.
  func initPlayfield() {
    playfield = Playfield(bounds: gameFrame)
    playfield.setZ(.playfield)
    gameArea.addChild(playfield)
  }

  /// Create the game area
  ///
  /// The main game scene avoids the safe area since I don't want the player's ship
  /// to get into regions where it's obscured.  Other scenes go edge-to-edge.
  ///
  /// Currently the aspect ratio restriction is never used.  It might make sense to
  /// limit the aspect ratio for phones though, since otherwise there's a lot of
  /// left-right area.
  ///
  /// This should be called at initialization time, but it needs to be done from one
  /// of `BasicScene`'s subclasses, since only they know whether or not to avoid the
  /// safe area.
  ///
  /// - Parameters:
  ///   - avoidSafeArea: `true` if the device's safe area should be excluded
  ///   - maxAspectRatio: Maximum desired aspect ratio of the area
  func initGameArea(avoidSafeArea: Bool, maxAspectRatio: CGFloat = .infinity) {
    var width = size.width
    if avoidSafeArea {
      width -= Globals.safeAreaPaddingLeft
      width -= Globals.safeAreaPaddingRight
    }
    if width / size.height > maxAspectRatio {
      width = size.height * maxAspectRatio
    }
    gameFrame = CGRect(x: -0.5 * width, y: -0.5 * size.height, width: width, height: size.height)
    gameAreaCrop.name = "gameAreaCrop"
    if gameFrame.width == fullFrame.width {
      gameAreaCrop.maskNode = nil
    } else {
      let mask = SKShapeNode(rect: gameFrame)
      mask.fillColor = .white
      mask.strokeColor = .clear
      gameAreaCrop.maskNode = mask
      // Add a background for the background ;-).  This is set to match the
      // transition color so that it doesn't stand out if the transition is a bit
      // fancier than a simple fade.
      let bgColor = SKSpriteNode()
      bgColor.color = AppAppearance.transitionColor
      bgColor.size = fullFrame.size
      bgColor.position = CGPoint(x: fullFrame.midX, y: fullFrame.midY)
      bgColor.setZ(.background)
      bgColor.blendMode = .replace
      addChild(bgColor)
    }
    addChild(gameAreaCrop)
    gameArea.name = "gameArea"
    gameArea.shader = nil
    gameArea.shouldEnableEffects = false
    gameAreaCrop.addChild(gameArea)
    initBackground()
    initStars()
    initPlayfield()
    audio = SceneAudio(stereoEffectsFrame: gameFrame, audioEngine: audioEngine)
  }

  /// Initialize a new basic scene of a given size
  ///
  /// This should be overridden by subclasses of `BasicScene`, but be sure to call
  /// `super.init()`.  The subclass initializer should also call `initGameArea`
  /// (which is defined in `BasicScene`).  It can't be called here because only the
  /// subclass knows whether it wants to be full screen or clip the game area to the
  /// device's safe area.
  override init(size: CGSize) {
    super.init(size: size)
    os_log("BasicScene init %{public}s", log: .app, type: .debug, "\(self.hash)")
    fullFrame = CGRect(x: -0.5 * size.width, y: -0.5 * size.height, width: size.width, height: size.height)
    scaleMode = .aspectFill
    anchorPoint = CGPoint(x: 0.5, y: 0.5)
    physicsWorld.gravity = .zero
    preloadAsteroidSplitEffects()
  }

  required init(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented by BasicScene or its subclasses")
  }

  // MARK: - Deinitialization

  /// Remove actions from an entire node hierarchy
  /// - Parameter node: The root of the hierarchy
  func removeActionsForEverything(node: SKNode) {
    node.removeAllActions()
    for child in node.children {
      removeActionsForEverything(node: child)
    }
  }

  /// Get a scene into a collectable state
  ///
  /// Call `cleanup` from `willMove(from:)` when a scene will be destroyed if the
  /// scene's state is uncertain.  I use this for game scenes especially because it's
  /// hard to be sure of a consistent state at the time of scene transition because
  /// of the possibility that the player quit in the middle of the game.  At the time
  /// of the quit, the game is paused, so all kinds of actions and things may be
  /// running, the playfield may be full of sprites, etc.  I need to fix up
  /// everything so that the scene will get garbage collected cleanly.  First tell
  /// the playfield to recycle sprites.  Then cancel all actions so that any closures
  /// which may have captured something that would lead to a retain cycle get nuked
  /// from orbit.
  func cleanup() {
    playfield.recycle()
    removeActionsForEverything(node: self)
  }

  // MARK: - Pausing

  /// Pauses the scene when set.  This is an override of SKScene's property of the
  /// same name because SpriteKit's automatic pausing/unpausing for stuff like the
  /// app going into the background/foreground can screw things up if the scene is
  /// paused because it's doing something like presenting another view controller or
  /// waiting to resume a paused game.  The subclass should override the forcePause
  /// property to return true when it's in a state where the scene should not unpause
  /// as a result of SpriteKit's behind-the-scenes mucking.
  override var isPaused: Bool {
    get { super.isPaused }
    set {
      if forcePause && !newValue {
        os_log("holding isPaused at true because forcePause is true", log: .app, type: .debug)
      }
      super.isPaused = newValue || forcePause
    }
  }

  /// Subclasses override this to indicate when they should remain paused despite
  /// SpriteKit's best efforts to mess them up.
  var forcePause: Bool { false }

  /// (Conceptually) turn the game area's filter on or off; see full discussion below
  ///
  /// The filter is used when a game is paused to blur the game area (except for the
  /// resume/cancel buttons).
  ///
  /// `gameArea` is an `SKEffectNode`.  Originally its `filter` property was set and
  /// this routine was basically just `gameArea.shouldEnableEffects = enable`.
  /// However, repeated pausing and unpausing would cause a memory leak.  How is not
  /// clear; something internal to the way the effect node and CI filters interact I
  /// think, but why beats me.  I could pump the memory up from ~150-200MB normally
  /// to 500-600MB by pausing/unpausing/aborting, and undoubtedly could have gotten
  /// it higher if I were patient.  Also, leak checking showed that the scene was
  /// being collected fine upon end-of-game or aborting a game, so it didn't seem to
  /// have anything to do with something that I was retaining.
  ///
  /// The one I did originally was to render `gameArea` to a texture, run that
  /// explicitly through a `CGImage`, `CIFilter`, `CGImage` `SKTexture` sequence, and
  /// make a sprite with that effect texture above the game area.  It's kind of ugly
  /// and awkward, though it does offer one benefit, in that I could use the regular
  /// scene transition stuff (which requires the scene to be unpaused) during an
  /// abort, and this approach would let it appear as if the game was paused
  /// throughout the transition.  The main drawback of this approach (aside from the
  /// hackish nature) was that there would be a slight lag when pressing the pause
  /// button before the paused texture could be constructed and shown.  (In the case
  /// of the non-retro Gaussian blur filter that I was using, it was possible to
  /// avoid this by rendering `gameArea` at a smaller scale and blurring that.  But
  /// that didn't help the retro case.)
  ///
  /// The second option seems cleaner and is what I've switched to.  That's to use a
  /// shader instead of a CI filter for the effect.  The fact that this avoids the
  /// leak without explicit off-screen rendering and filtering also supports the idea
  /// that the problem is not something in the app's code but something in the
  /// internal use of CI filters by the effect node.  The main issue was getting a
  /// shader that looks reasonable with retro mode, and I've had to split into
  /// separate pause shaders to get something that passes muster.  The other thing to
  /// consider with a shader is that the texture it works on is varying in size, so
  /// whatever it is needs to be something that works nicely for varying sizes and
  /// aspect ratios and offsets.  I had to assume Metal under the hood so that I
  /// could use the `get_width()` and `get_height()` methods on the texture.  I've
  /// left an alternative Gaussian shader in the code that could probably be adapted
  /// to work without that assumption, though it would suck with retro.
  ///
  /// - Parameter enable: `true` if the filter should be turned on
  func setGameAreaBlur(_ enable: Bool) {
    gameArea.shouldEnableEffects = enable && shader != nil
  }

  // MARK: - Pause shaders

  /// The pause shader for non-retro mode
  static let pauseShaderModern: SKShader = {
    // This is a sort of pixellated checkerboard
    let rgba = AppAppearance.darkBlue.cgColor.components!
    let shaderSource = """
    void main() {
      float const sq = 10.0;
      // Get texture size (assumes Metal)
      int width = u_texture.get_width();
      int height = u_texture.get_height();
      // Compute pixel size
      vec2 pixel(1.0 / width, 1.0 / height);
      // View the texture as sqxsq pixel squares; compute the x and y indicies of the square
      // for the current pixel
      vec2 center = floor(v_tex_coord / pixel / sq);
      if ((int(center.x) + int(center.y)) % 2 == 0) {
        // Half the squares are the background color; could also consider the
        // transition color
        gl_FragColor = vec4(\(rgba[0]), \(rgba[1]), \(rgba[2]), 1.0);
      } else {
        // For the other half, sample one color from the center of the square
        center += 0.5;
        center *= sq * pixel;
        gl_FragColor = texture2D(u_texture, center);
      }
    }
    """
    return SKShader(source: shaderSource)
  }()

  /// An alternate pause shader for non-retro mode based on a Gaussian blur
  ///
  /// This isn't currently used, but I'm not 100% decided about the shader, so I've left it.
  static let pauseShaderModernGaussian: SKShader = {
    let rgba = AppAppearance.darkBlue.cgColor.components!
    let shaderSource = """
    void main() {
      // Get texture size (assumes Metal)
      int width = u_texture.get_width();
      int height = u_texture.get_height();
      // Compute pixel size
      vec2 pixel(1.0 / width, 1.0 / height);
      // Size of steps between blur samples (determines the radius)
      vec2 d = 3 * pixel;
      // 1D discrete Gaussian weights
      int const np = 5;
      float wts[np] = { 0.06136, 0.24477, 0.38774, 0.24477, 0.06136 };
      // int const np = 7;
      // float wts[np] = { 0.00598, 0.060626, 0.241843, 0.383103, 0.241843, 0.060626, 0.00598 };
      int const halfnp = (np - 1) / 2;
      vec4 result(0.0);
      // Sample textures in a npxnp grid and accumulate with appropriate weights
      for (int i = -halfnp; i <= halfnp; ++i) {
        for (int j = -halfnp; j <= halfnp; ++j) {
          result += wts[i + halfnp] * wts[j + halfnp] * texture2D(u_texture, v_tex_coord + vec2(i * d.x, j * d.y));
        }
      }
      gl_FragColor = result;
    }
    """
    return SKShader(source: shaderSource)
  }()

  /// The pause shader for retro mode
  static let pauseShaderRetro: SKShader = {
    // This is an analog of the standard pause shader, but adapted a bit because the
    // retro shader is going to run on top of it.  This isn't 100% perfect; it'll
    // occasionally cause some effects at the very edge of the screen because of the
    // way the square alignment falls compared to what the retro shader is looking
    // at. But it's not ridiculous, and for whatever reason it seems to happen mostly
    // on my phone.  Maybe something to do with the display resolution?  Anyway...
    let rgba = AppAppearance.darkBlue.cgColor.components!
    let shaderSource = """
    void main() {
      float const sq = 7.0;
      // Get texture size (assumes Metal)
      int width = u_texture.get_width();
      int height = u_texture.get_height();
      // Compute pixel size
      vec2 pixel(1.0 / width, 1.0 / height);
      vec2 center = floor(v_tex_coord / pixel / sq);
      // The most important change is not to use a checkerboard but just pixelate
      // everything.
      // Sample a color from the center of the square, so solid areas disappear
      // under the retro shader.
      center += 0.5;
      center *= sq * pixel;
      gl_FragColor = texture2D(u_texture, center);
    }
    """
    return SKShader(source: shaderSource)
  }()

  // MARK: - Asteroids

  /// Create an asteroid and add it to the playfield
  ///
  /// `onScreen` is `false` for newly created asteroids.  They're off the screen, and
  /// their coordinates should not start wrapping until they enter the playfield and
  /// become visible.
  ///
  /// - Parameters:
  ///   - pos: The starting position of the asteroid
  ///   - size: The size of the asteroid
  ///   - velocity: The velocity of the asteroid
  ///   - onScreen: `false` if the asteroid is not on screen
  func makeAsteroid(position pos: CGPoint, size: AsteroidSize, velocity: CGVector, onScreen: Bool) {
    let numTypes = [2, 2, 4, 3][size.sizeIndex]
    var type = Int.random(in: 1 ... numTypes)
    if Int.random(in: 1 ... 4) != 1 {
      // Prefer the last type for each size (where I can use a circular physics
      // body), rest just for variety.
      type = numTypes
    }
    var name = "meteor\(size)\(type)"
    // For amusement, if the player has gotten the Little Prince achievement, then on
    // rare occasions spawn an asteroid with the Prince and his friends on it.
    if littlePrinceAllowed && size == .huge && type == numTypes &&
      Int.random(in: 0 ..< 100) == 0 && achievementIsCompleted(.littlePrince) {
      name = "meteorhugeprince"
      // Don't allow another until liitlePrinceAllowed is reset
      littlePrinceAllowed = false
    }
    let asteroid = Globals.spriteCache.findSprite(imageNamed: name) { sprite in
      let texture: SKTexture
      if name == "meteorhugeprince" {
        // The Litte Prince asteroid texture is the same as the last huge asteroid
        // texture but enlarged slightly and with some decoration.  Use the unadorned
        // texture for the physics body though.
        texture = Globals.textureCache.findTexture(imageNamed: "meteor\(size)\(type)")
      } else {
        texture = sprite.requiredTexture()
      }
      // Huge and big asteroids of all types except the default have irregular shape,
      // so I use a pixel-perfect physics body for those.  Everything else gets a
      // circle.
      let body = (type == numTypes || size == .med || size == .small ?
        SKPhysicsBody(circleOfRadius: 0.5 * texture.size().width) :
        Globals.conformingPhysicsCache.makeBody(texture: texture))
      body.angularDamping = 0
      body.linearDamping = 0
      body.categoryBitMask = size.category.rawValue
      body.collisionBitMask = 0
      body.contactTestBitMask = setOf([.player, .playerShot, .ufo, .ufoShot])
      body.restitution = 0.9
      sprite.physicsBody = body
    }
    asteroid.position = pos
    let minSpeed = Globals.gameConfig.asteroidMinSpeed
    let maxSpeed = Globals.gameConfig.asteroidMaxSpeed
    var finalVelocity = velocity
    let speed = velocity.length()
    if speed == 0 {
      finalVelocity = CGVector(angle: .random(in: 0 ... 2 * .pi)).scale(by: .random(in: minSpeed ... maxSpeed))
    } else if speed < minSpeed {
      finalVelocity = velocity.scale(by: minSpeed / speed)
    } else if speed > maxSpeed {
      finalVelocity = velocity.scale(by: maxSpeed / speed)
    }
    // Important: addWithScaling must be done BEFORE setting the velocity.  If it's
    // after, then the addChild mucks with the velocity a little bit, which is
    // totally bizarre and also can totally screw things up.  If the asteroid is
    // being spawned, I've calculated the initial position and velocity so that it
    // will get onto the screen, but if the velocity gets tweaked, then that
    // guarantee is out the window.
    playfield.addWithScaling(asteroid)
    let body = asteroid.requiredPhysicsBody()
    body.velocity = finalVelocity
    body.isOnScreen = onScreen
    body.angularVelocity = .random(in: -.pi ... .pi)
    asteroids.insert(asteroid)
  }

  /// Create a new asteroid somewhere off the screen
  ///
  /// The asteroid will have velocity that brings it onto the screen in a few seconds.
  ///
  /// - Parameter size: The size of the asteroid to spawn
  func spawnAsteroid(size: AsteroidSize) {
    // Initial direction of the asteroid from the center of the screen
    let dir = CGVector(angle: .random(in: -.pi ... .pi))
    // Traveling towards the center at a random speed
    let minSpeed = Globals.gameConfig.asteroidMinSpeed
    let maxSpeed = Globals.gameConfig.asteroidMaxSpeed
    let speed = CGFloat.random(in: minSpeed ... max(min(4 * minSpeed, 0.33 * maxSpeed), 0.25 * maxSpeed))
    let velocity = dir.scale(by: -speed)
    // Offset from the center by some random amount
    let offset = CGPoint(x: .random(in: 0.75 * gameFrame.minX ... 0.75 * gameFrame.maxX),
                         y: .random(in: 0.75 * gameFrame.minY ... 0.75 * gameFrame.maxY))
    // Find a random distance that places us beyond the screen by a reasonable amount
    var dist = .random(in: 0.25 ... 0.5) * gameFrame.height
    let minExclusion = max(1.25 * speed, 50)
    let maxExclusion = max(3.5 * speed, 200)
    let exclusion = -CGFloat.random(in: minExclusion ... maxExclusion)
    while gameFrame.insetBy(dx: exclusion, dy: exclusion).contains(offset + dir.scale(by: dist)) {
      dist *= 1.1
    }
    makeAsteroid(position: offset + dir.scale(by: dist), size: size, velocity: velocity, onScreen: false)
  }

  /// This is called after an asteroid is removed
  ///
  /// Subclasses should override this to do additional work or checks when an
  /// asteroid is removed.  E.g., the game scene sees if there are no more asteroids,
  /// and if not, spawns a new wave.
  func asteroidRemoved() { }

  /// Remove an asteroid that got hit by something
  ///
  /// If a subclass needs to do something when an asteroid is removed (e.g., check
  /// for no more asteroids), then they should override `asteroidRemoved`, not this.
  ///
  /// - Parameter asteroid: The asteroid to remove
  func removeAsteroid(_ asteroid: SKSpriteNode) {
    Globals.spriteCache.recycleSprite(asteroid)
    asteroids.remove(asteroid)
    asteroidRemoved()
  }

  /// Create an emitter node for splitting an asteroid
  ///
  /// The emitter depends on the asteroid's size (more bits and a bigger radius for
  /// bigger asteroids).
  ///
  /// - Parameter size: The size of the asteroid
  func getAsteroidSplitEffect(size: AsteroidSize) -> SKEmitterNode {
    let texture = Globals.textureCache.findTexture(imageNamed: "meteor\(size.sizeString)1")
    let emitter = SKEmitterNode()
    emitter.particleTexture = Globals.textureCache.findTexture(imageNamed: "meteorsmall1")
    let effectDuration = CGFloat(0.25)
    emitter.particleLifetime = effectDuration
    emitter.particleLifetimeRange = 0.15 * effectDuration
    emitter.particleScale = 0.75
    emitter.particleScaleRange = 0.25
    emitter.numParticlesToEmit = 4 * size.sizeIndex
    emitter.particleBirthRate = CGFloat(emitter.numParticlesToEmit) / (0.25 * effectDuration)
    let radius = 0.75 * texture.size().width
    emitter.particleSpeed = radius / effectDuration
    emitter.particleSpeedRange = 0.25 * emitter.particleSpeed
    emitter.particlePosition = .zero
    emitter.particlePositionRange = CGVector(dx: radius, dy: radius).scale(by: 0.25)
    emitter.emissionAngle = 0
    emitter.emissionAngleRange = 2 * .pi
    emitter.particleRotation = 0
    emitter.particleRotationRange = .pi
    emitter.particleRotationSpeed = 2 * .pi / effectDuration
    emitter.particleRenderOrder = .dontCare
    emitter.isPaused = true
    emitter.name = "asteroidSplitEmitter"
    return emitter
  }

  /// Pre-creates a bunch of asteroid split emitter nodes
  ///
  /// These get recycled repeatedly during a game as asteroids are destroyed.
  func preloadAsteroidSplitEffects() {
    for size in [AsteroidSize.huge, .big, .med] {
      Globals.asteroidSplitEffectsCache.load(count: 10, forKey: size) { getAsteroidSplitEffect(size: size) }
    }
  }

  /// Show an emitter node that looks like rock debris at an asteroid's position
  /// - Parameters:
  ///   - asteroid: The asteroid that was hit
  ///   - size: The size of the asteroid
  func makeAsteroidSplitEffect(_ asteroid: SKSpriteNode, size: AsteroidSize) {
    let emitter = Globals.asteroidSplitEffectsCache.next(forKey: size)
    if emitter.parent != nil {
      emitter.removeFromParent()
    }
    emitter.removeAllActions()
    emitter.run(.wait(for: 0.5, then: .removeFromParent()))
    emitter.position = asteroid.position
    emitter.isPaused = true
    emitter.resetSimulation()
    emitter.isPaused = false
    playfield.addWithScaling(emitter)
  }

  /// Destroy an asteroid and maybe spawn child asteroids
  /// - Parameter asteroid: The asteroid that was hit by something
  func splitAsteroid(_ asteroid: SKSpriteNode) {
    let body = asteroid.requiredPhysicsBody()
    guard let size = AsteroidSize(ofBody: body) else { fatalError("Could not get asteroid size for sprite") }
    let sizeIndex = size.sizeIndex
    let velocity = body.velocity
    let pos = asteroid.position
    makeAsteroidSplitEffect(asteroid, size: size)
    audio.soundEffect([.asteroidSmallHit, .asteroidMedHit, .asteroidBigHit, .asteroidHugeHit][sizeIndex], at: pos)
    // Don't split med or small asteroids.  Size progression should go huge -> big -> med,
    // but I include small just for completeness in case I change my mind later.
    if size == .big || size == .huge {
      // Choose a random direction for the first child and project to get that child's velocity
      let velocity1Angle = CGVector(angle: velocity.angle() + .random(in: -0.4 * .pi ... 0.4 * .pi))
      // Throw in a random scaling just to keep it from being too uniform
      let velocity1 = velocity.project(unitVector: velocity1Angle).scale(by: .random(in: 0.75 ... 1.25))
      // The second child's velocity is chosen from momentum conservation
      let velocity2 = velocity.scale(by: 2) - velocity1
      // Add a bit of extra spice just to keep the player on their toes
      let oomph = Globals.gameConfig.value(for: \.asteroidSpeedBoost)
      let smaller = size.smaller
      makeAsteroid(position: pos, size: smaller, velocity: velocity1.scale(by: oomph), onScreen: true)
      makeAsteroid(position: pos, size: smaller, velocity: velocity2.scale(by: oomph), onScreen: true)
    }
    removeAsteroid(asteroid)
  }

  // MARK: - UFOs

  /// Create a UFO shot
  ///
  /// When a shot gets created, it also gets an action that will automatically remove
  /// it after it has travelled an appropriate amount of time.  The action will
  /// handle the case of shots that miss, and the physics engine will signal
  /// collisions for shots that don't.
  ///
  /// - Parameters:
  ///   - angle: The shot's direction of travel
  ///   - position: The starting position of the shot
  ///   - speed: How fast the shot should travel
  func fireUFOLaser(angle: CGFloat, position: CGPoint, speed: CGFloat) {
    let laser = Globals.spriteCache.findSprite(imageNamed: "lasersmall_red") { sprite in
      let texture = sprite.requiredTexture()
      let ht = texture.size().height
      let body = SKPhysicsBody(circleOfRadius: 0.5 * ht,
                               center: CGPoint(x: 0.5 * (texture.size().width - ht), y: 0))
      body.allowsRotation = false
      body.linearDamping = 0
      body.categoryBitMask = ObjectCategories.ufoShot.rawValue
      body.collisionBitMask = 0
      body.contactTestBitMask = setOf([.asteroid, .player])
      sprite.physicsBody = body
    }
    laser.wait(for: Double(0.9 * gameFrame.height / speed)) { self.removeUFOLaser(laser) }
    playfield.addWithScaling(laser)
    laser.position = position
    laser.zRotation = angle
    laser.requiredPhysicsBody().velocity = CGVector(angle: angle).scale(by: speed)
    audio.soundEffect(.ufoShot, at: position)
  }

  /// Destory a UFO shot
  /// - Parameter laser: The shot to clean up
  func removeUFOLaser(_ laser: SKSpriteNode) {
    assert(laser.name == "lasersmall_red")
    Globals.spriteCache.recycleSprite(laser)
  }

  /// Add some sort of effect to the playfield
  /// - Parameter nodes: The things to add
  func addToPlayfield(_ nodes: [SKNode]) {
    for node in nodes {
      playfield.addWithScaling(node)
    }
  }

  /// Remove a UFO from the set of UFOs
  ///
  /// This is a separate function in case a subclass needs to override it to do some
  /// housekeeping of its own when a UFO is removed.
  ///
  /// - Parameter ufo: The UFO to remove
  func removeUFO(_ ufo: UFO) {
    ufos.remove(ufo)
  }

  /// Make a UFO warp out immediately, with suitable visual effect
  ///
  /// Be careful when calling this directly because of UFOs that may have spawned but
  /// not launched.  If trying to get rid of all UFOs, use `warpOutUFOs`.
  ///
  /// - Parameter ufo: The UFO that should warp
  func warpOutUFO(_ ufo: UFO) {
    audio.soundEffect(.ufoWarpOut, at: ufo.position)
    addToPlayfield(ufo.warpOut())
    removeUFO(ufo)
  }

  /// Make all UFOs jump to hyperspace and leave the playfield
  ///
  /// This is the method to call to get rid of UFOs.  For example, the main menu
  /// calls this when a UFO is flying around and the player wants to start a new game
  /// or something.  In the game, the UFOs leave after the player dies.
  ///
  /// This method also takes care of removing UFOs that have spawned by not launched
  /// (see discussion below and in `spawnUFO`).
  ///
  /// - Parameter averageDelay: Approximate amount of time before the UFO warps
  /// - Returns: The maximum delay among all the UFOs; wait at least this long
  ///   before scene transition, respawn, etc.
  func warpOutUFOs(averageDelay: Double = 1) -> Double {
    // This is a little involved, but here's the idea.  The player has just died and
    // I've delayed a bit to let any of his existing shots hit stuff.  After the
    // shots are gone, any remaining UFOs will warp out before the player respawns or
    // I show Game Over.  I warp out the UFOs by having each run an action that waits
    // for a random delay before calling ufo.warpOut.  While the UFO is delaying
    // though, it might hit an asteroid and be destroyed, so the action has a
    // "warpOut" key through which I can cancel it.  This function returns the
    // maximum warpOut delay for all the UFOs; respawnOrGameOver will wait a bit
    // longer than that before triggering whatever it's going to do.
    //
    // One further caveat...
    //
    // When a UFO gets added by spawnUFO, it's initially off the playfield to the
    // left or right, but its audio will start so as to give the player a chance to
    // prepare.  After a second, an action will trigger to launch the UFO.  The UFO
    // gets moved vertically to a good spot and its velocity is set so that it will
    // move and become visible, and as soon as isOnScreen becomes true, it will start
    // flying normally.  For warpOuts of these launched UFOs, everything will happen
    // as you expect with the usual animations.  However, for a UFO that has been
    // spawned but not yet launched, warpOutUFOs should still get rid of it.  These
    // I'll just nuke immediately, but be sure to call their cleanup method to give
    // them a chance to do any housekeeping that they may need.
    var maxDelay = 0.0
    ufos.forEach { ufo in
      if ufo.requiredPhysicsBody().isOnScreen {
        let delay = Double.random(in: 0.5 * averageDelay ... 1.5 * averageDelay)
        maxDelay = max(maxDelay, delay)
        ufo.run(.wait(for: delay) { self.warpOutUFO(ufo) }, withKey: "warpOut")
      } else {
        os_log("Cleanup on unlaunched ufo", log: .app, type: .debug)
        ufo.cleanup()
        removeUFO(ufo)
      }
    }
    return maxDelay
  }

  /// Make a UFO enter the game area
  ///
  /// UFO spawning is a two step process.
  ///
  /// This method is the first step; it picks a side (left or right) for the
  /// newly-created and then places the UFO just off the screen on that side (and in
  /// the middle vertically, but that will change).  Then there's a pause.  The UFO's
  /// audio will be running during that time, and since the UFO's left-or-right
  /// location is set, the player will get an audio clue as to which side the UFO
  /// will enter on.  (Provided they're wearing headphones or using something like an
  /// iPad Pro with speakers that can do stereo while in landscape mode.)
  ///
  /// `launchUFO` is scheduled for after the pause.  That method searches for a
  /// suitable vertical position for the UFO to enter.  Then it sets the UFOs
  /// velocity to direct it onto the playfield and turns on `isDyanmic` so that the
  /// physics engine will start moving the UFO.
  ///
  /// - Parameter ufo: The new UFO that will enter
  func spawnUFO(ufo: UFO) {
    playfield.addWithScaling(ufo)
    ufos.insert(ufo)
    // Position the UFO off the screen on one side or another.  I set the side here
    // so that the positional audio will give a clue about where it's coming from.
    // Actual choice of Y position and beginning of movement happens after a delay.
    // The offset should be large enough that there's no chance of a collision being
    // flagged between the player or their shots (which will be wrapping).  At launch
    // time, I'll move the UFO a bit closer.
    let ufoOffset = CGFloat(150)
    let x = (Bool.random() ? gameFrame.maxX + ufoOffset : gameFrame.minX - ufoOffset)
    // Audio depends only on left/right, i.e., x.
    ufo.position = CGPoint(x: x, y: 0)
    wait(for: 1) { self.launchUFO(ufo) }
  }

  /// Move a UFO on to the playfield; see discussion under `spawnUFO`
  /// - Parameter ufo: The UFO to launch
  func launchUFO(_ ufo: UFO) {
    let ufoRadius = 0.5 * ufo.size.width
    // Try to find a safe spawning position, but if I can't find one after some
    // number of tries, just go ahead and spawn anyway.
    var bestPosition: CGPoint?
    var bestClearance = CGFloat.infinity
    // Th UFO is initially a bit farther off the screen than is desirable for
    // launching.  I'll adjust the X position so it's just barely off.
    let ufoX: CGFloat
    if ufo.position.x > gameFrame.maxX {
      ufoX = gameFrame.maxX + 1.1 * ufoRadius
    } else {
      ufoX = gameFrame.minX - 1.1 * ufoRadius
    }
    for _ in 0 ..< 10 {
      let pos = CGPoint(x: ufoX, y: .random(in: 0.9 * gameFrame.minY ... 0.9 * gameFrame.maxY))
      var thisClearance = CGFloat.infinity
      for asteroid in asteroids {
        let bothRadii = ufoRadius + 0.5 * asteroid.size.diagonal()
        thisClearance = min(thisClearance, (asteroid.position - pos).length() - bothRadii)
        // Check the wrapped position too
        thisClearance = min(thisClearance, (asteroid.position - CGPoint(x: -pos.x, y: pos.y)).length() - bothRadii)
      }
      if bestPosition == nil || thisClearance > bestClearance {
        bestPosition = pos
        bestClearance = thisClearance
      }
      if bestClearance > 5 * ufoRadius {
        break
      }
    }
    ufo.position = bestPosition!
    let body = ufo.requiredPhysicsBody()
    body.isDynamic = true
    body.velocity = CGVector(dx: copysign(ufo.currentSpeed, -ufo.position.x), dy: 0)
  }

  /// Destroy a UFO
  ///
  /// Requires a bit of care because UFOs may have actions scheduled when this gets
  /// called.
  ///
  /// - Parameters:
  ///   - ufo: The UFO to nuke
  ///   - collision: `true` if this is the result of a ship-ship collision
  func destroyUFO(_ ufo: UFO, collision: Bool) {
    // If the player was destroyed earlier, the UFO will have been scheduled for
    // warpOut.  But if it just got destroyed (by hitting an asteroid) I have to be
    // sure to cancel the warp.
    ufo.removeAction(forKey: "warpOut")
    audio.soundEffect(.ufoExplosion, at: ufo.position)
    addToPlayfield(ufo.explode(collision: collision))
    removeUFO(ufo)
  }

  // MARK: - Contact handling

  /// Handle a collision between a UFO shot and an asteroid
  /// - Parameters:
  ///   - laser: The UFO's shot
  ///   - asteroid: The asteroid that it hit
  func ufoLaserHit(laser: SKNode, asteroid: SKNode) {
    removeUFOLaser(laser as! SKSpriteNode)
    splitAsteroid(asteroid as! SKSpriteNode)
  }

  /// Handle a collision between a UFO and an asteroid
  /// - Parameters:
  ///   - ufo: The UFO
  ///   - asteroid: The asteroid
  func ufoCollided(ufo: SKNode, asteroid: SKNode) {
    // I'm not sure if this check is needed anyway, but non-launched UFOs have
    // isDynamic set to false so that they're holding.  Make sure that the UFO has
    // been launched before flagging a collision.
    guard ufo.requiredPhysicsBody().isDynamic else { return }
    splitAsteroid(asteroid as! SKSpriteNode)
    // This one doesn't count as a collision for UFO explosion purposes since the
    // asteroid doesn't make a bunch of fragments
    destroyUFO(ufo as! UFO, collision: false)
  }

  /// Handle a collision between two UFOs
  /// - Parameters:
  ///   - ufo1: First UFO
  ///   - ufo2: Second UFO
  func ufosCollided(ufo1: SKNode, ufo2: SKNode) {
    // I'm not sure if these check is needed anyway, but non-launched UFOs have
    // isDynamic set to false so that they're holding.  Make sure that the UFO has
    // been launched before flagging a collision.
    guard ufo1.requiredPhysicsBody().isDynamic else { return }
    guard ufo2.requiredPhysicsBody().isDynamic else { return }
    destroyUFO(ufo1 as! UFO, collision: true)
    destroyUFO(ufo2 as! UFO, collision: true)
  }

  /// Handle a contact notice from the physics engine for objects of a given type
  ///
  /// Subclasses should provide a didBegin method and set themselves as the
  /// contactDelegate for physicsWorld.  E.g. ```
  ///  func didBegin(_ contact: SKPhysicsContact) {
  ///    when(contact, isBetween: .ufoShot, and: .asteroid) { ufoLaserHit(laser: $0, asteroid: $1) }
  ///    when(contact, isBetween: .ufo, and: .asteroid) { ufoCollided(ufo: $0, asteroid: $1) }
  ///    ...
  ///  }
  /// ```
  ///
  /// This method handles making sure the objects are still active in the scene (in
  /// case a previous contact did something to them) and getting the objects into the
  /// right order for the action according to their category.
  ///
  /// - Parameters:
  ///   - contact: The contact info from the physics engine
  ///   - type1: Category for node 1 in the action
  ///   - type2: Category for node 2 in the action
  ///   - action: What to do
  ///   - node1: Node 1 for the action
  ///   - node2: Node 2 for the action
  func when(_ contact: SKPhysicsContact,
            isBetween type1: ObjectCategories, and type2: ObjectCategories,
            action: (_ node1: SKNode, _ node2: SKNode) -> Void) {
    let b1 = contact.bodyA
    let b2 = contact.bodyB
    guard let node1 = contact.bodyA.node, node1.parent != nil else { return }
    guard let node2 = contact.bodyB.node, node2.parent != nil else { return }
    if b1.isA(type1) && b2.isA(type2) {
      action(node1, node2)
    } else if b2.isA(type1) && b1.isA(type2) {
      action(node2, node1)
    }
  }

  // MARK: - Scene transition shaders

  /// A shader that just makes the app's transition color
  static let maskingShader: SKShader = {
    let rgba = AppAppearance.transitionColor.cgColor.components!
    let shaderSource = """
    void main() {
      gl_FragColor = vec4(\(rgba[0]), \(rgba[1]), \(rgba[2]), 1.0);
    }
    """
    return SKShader(source: shaderSource)
  }()

  /// Time for in and out transitions (total transition time is twice this, plus
  /// whatever overhead)
  static let transitionDuration = 0.5
  /// Shader for scenes that are starting to be shown
  static let entryShader = enterExitShader(isEntering: true, duration: transitionDuration)
  /// Shader for scenes that are finished being shown
  static let exitShader = enterExitShader(isEntering: false, duration: transitionDuration)

  // MARK: - Scene switching

  /// Use `guard beginSceneSwitch` before starting scene transitions
  ///
  /// Things like button actions that switch scenes must call this at the start of
  /// the process, and should abort immediately if the return value is `false`.  This
  /// is used to avoid race conditions between actions that would like to switch
  /// scenes.  The first action sets `switchingScenes` to `true` by calling this and
  /// receives the go-ahead.  Subsequent actions are informed that scene switching is
  /// already in progress.
  ///
  /// - Returns: `true` means proceed, `false` indicates that some other scene switch is happening
  func beginSceneSwitch() -> Bool {
    if switchingScenes {
      os_log("beginSceneSwitch says no", log: .app, type: .debug)
      return false
    } else {
      switchingScenes = true
      return true
    }
  }

  // Scene transitions are a bit subtle, but here's the idea.
  //
  // The basic problem is that when the app needs to transition to a new scene, it
  // usually has to create one (the exception is the case of going back to the main
  // menu).  That creation process tends to cause frame lag, even when I run it on a
  // background thread with low priority.  But the transitions I was using initially
  // were just a simple fade-out-then-fade-in.  Then I realized that if I could
  // somehow do the scene construction in the middle of the transition, any lag would
  // be irrelevant since the app would be displaying a static (blank) graphic anyway.
  // That idea led to the current mechanism.
  //
  // Transitions now consist of three parts:
  // 1. Outgoing transition of the current scene
  // 2. Scene creation
  // 3. Incoming transition of the new scene
  //
  // Each phase of a transitions is managed via a sprite node with zPosition at
  // LevelZs.transition.  That's above everything else.  The sprite has a trivial
  // texture which isn't really used for anything, and it has a size and position
  // that covers the whole frame.  The sprite is basically a mask.  In some places it
  // shows the underlying scene, and in others it shows the app's background color.
  // The masking behavior is controlled by the sprite's shader, which determines what
  // to hide and what to show as a function of time.
  //
  // When a scene wants to make a transition, it calls `switchScene(withFade:)`,
  // `switchScene`, or `switchWhenQuiescent` as appropriate.  The main argument is a
  // closure that returns the new scene (typically after creating it).  The first
  // function is used only on paused scenes (when aborting a game).  Because the
  // scene is paused, the display is already static.  The latter two functions make
  // an outgoing transition that installs a masking transition sprite in the current
  // scene and sets its shader to `BasicScene.exitShader`.  The sprite runs an action
  // to animate the shader.  After the animation finishes, the display is again
  // completely static.  Once the display is frozen, the closure to get the new scene
  // is invoked.
  //
  // The final stage is conceptually just to add a masking transition sprite in the
  // new scene and set its shader to run and reveal the scene.  Since the new scene
  // seems to take a few frames to get going and start updating at a reasonable rate,
  // I first go ahead and add a transition sprite to the new scene.  I set the shader
  // to `maskingShader`, which is just a static shader that hides the scene.  I also
  // set the masking sprite as the value for `entryTransition` in the new scene.
  // When the new scene starts invoking `update`, one of the steps there is to call
  // `doEntryTransition`.  When that function finds a non-nil `entryTransition`, it
  // starts an action to wait for another few frames and sets `entryTransition` back
  // to `nil`.  That action sets the shader to `BasicScene.entryShader`, which does
  // the entry transition to reveal the scene.  Once the shader finishes, the sprite
  // is removed.

  /// Make a transition sprite
  ///
  /// The sprite covers the whole view, and the sprite's shader will determine which
  /// parts of scene are hidden and which are shown.
  ///
  /// - Returns: A new mask sprite
  func makeTransitionMask() -> SKSpriteNode {
    let maxDimension = max(frame.width, frame.height)
    let size = CGSize(width: maxDimension, height: maxDimension)
    let sprite = SKSpriteNode(texture: Globals.textureCache.findTexture(imageNamed: "dot"), size: size)
    sprite.position = CGPoint(x: frame.midX, y: frame.midY)
    sprite.setZ(.transition)
    return sprite
  }

  /// Add an entry transition to the scene
  ///
  /// The scene will be hidden until it moves to a view and starts running.
  func makeEntryTransition() {
    // Add a transition mask and make it static to just hide the scene until it can
    // get going.
    let inTransition = makeTransitionMask()
    inTransition.shader = BasicScene.maskingShader
    addChild(inTransition)
    // Save the mask to signal doEntryTransition that it has work to do
    entryTransition = inTransition
  }

  /// Switch to a new incoming scene
  ///
  /// This function doesn't require the outgoing scene to be in any specific state,
  /// and it may be paused.  I use this directly when aborting a game in the middle;
  /// `withFade` is `true` in that case.  It's also called internally by the normal
  /// scene transitions after the outgoing transition has finished.  `withFade` is
  /// `false` then since the outgoing scene is already hidden.
  ///
  /// - Parameters:
  ///   - withFade: `true` means do a fade out/in, else just switch immediately
  ///   - getNextScene: A closure to return the incoming scene
  func switchScene(withFade: Bool, _ getNextScene: @escaping () -> BasicScene) {
    guard let view = view else { fatalError("Transitioning scene has no view") }
    // The outgoing scene is either completely hidden by the outgoing transition or
    // is paused.  Any lag now won't be visible, so get the next scene.
    os_signpost(.begin, log: .poi, name: "scene creation", signpostID: self.signpostID)
    let nextScene = getNextScene()
    os_signpost(.end, log: .poi, name: "scene creation", signpostID: self.signpostID)
    os_log("switchScene %{public}s -> %{public}s", log: .app, type: .debug, self.name!, nextScene.name!)
    // Give the new scene an incoming transition
    nextScene.makeEntryTransition()
    os_signpost(.begin, log: .poi, name: "presentScene", signpostID: self.signpostID)
    if withFade {
      // The duration doesn't really mean the same thing as the normal transition
      // duration, but whatevs
      let transition = SKTransition.fade(with: AppAppearance.transitionColor,
                                         duration: BasicScene.transitionDuration)
      view.presentScene(nextScene, transition: transition)
    } else {
      view.presentScene(nextScene)
    }
    os_signpost(.end, log: .poi, name: "presentScene", signpostID: self.signpostID)
  }

  /// Switch to a new scene (with no quiescene requirement)
  ///
  /// Most scene transitions would call `switchWhenQuiescent` instead of
  /// `switchScene`.  This function would only be used directly when the state of the
  /// current scene cannot be easily characterized (like when aborting a game in the
  /// middle).  When using this function, it will be the responsibility of the
  /// current scene's `willMove(from:)` to get the scene into a garbage-collectable
  /// state.  The current scene cannot be paused when calling this function because
  /// it relies on an action to do the switch after the outgoing transition runs.
  ///
  /// The `getNextScene` closure is called between an outgoing transition for the
  /// current scene and an incoming transition for the next one.  In the time between
  /// the two transitions, the app will be displaying something static, so framerate
  /// drops due to whatever the closure needs to do aren't an issue.
  ///
  /// - Parameter getNextScene: A closure returning the scene to switch to
  func switchScene(_ getNextScene: @escaping () -> BasicScene) {
    // Add an outgoing transition mask for the current scene
    let outTransition = makeTransitionMask()
    outTransition.shader = BasicScene.exitShader
    addChild(outTransition)
    outTransition.run(.setTime(effectTime: BasicScene.transitionDuration + 0.1) {
      self.switchScene(withFade: false, getNextScene)
      outTransition.removeFromParent()
    })
  }

  /// Wait for quiescence, then switch to a different scene
  /// - Parameter getNextScene: A closure that returns the scene to switch to
  func switchWhenQuiescent(_ getNextScene: @escaping () -> BasicScene) {
    if playfield.isQuiescent(transient: setOf([.playerShot, .ufo, .ufoShot, .fragment])) {
      switchScene(getNextScene)
    } else {
      wait(for: 0.1) { self.switchWhenQuiescent(getNextScene) }
    }
  }

  /// When first calling `update` for a new scene, start its entry transition
  func doEntryTransition() {
    if let entryTransition = entryTransition {
      os_log("%{public}s doEntryTransition", log: .app, type: .debug, name!)
      // Make sure that the scene has a few frames to get going
      wait(for: 0.1) {
        // Switch from the static maskingShader to the entryShader
        entryTransition.shader = BasicScene.entryShader
        // Run the transition, then remove the mask
        entryTransition.run(.setTime(effectTime: BasicScene.transitionDuration, then: .removeFromParent()))
      }
      self.entryTransition = nil
    }
  }

  /// Subclasses should override this to do stuff like start a new game
  override func didMove(to view: SKView) {
    os_log("%{public}s didMove to view", log: .app, type: .debug, name!)
    Globals.textureCache.stats()
    Globals.spriteCache.stats()
    Globals.explosionCache.stats()
    Globals.conformingPhysicsCache.stats()
    Globals.asteroidSplitEffectsCache.stats()
    Globals.sounds.stats()
  }

  /// Subclasses should override this if needed
  override func willMove(from view: SKView) {
    os_log("%s willMove from view", log: .app, type: .debug, name!)
    removeAllActions()
  }

  // MARK: - Main update loop

  /// The update loop
  ///
  /// Subclasses should provide an update method with their own frame logic, e.g., ```
  ///  override func update(_ currentTime: TimeInterval) {
  ///    super.update(currentTime)
  ///    ufos.forEach {
  ///      $0.fly(player: player, playfield: playfield) {
  ///        (angle, position, speed) in self.fireUFOLaser(angle: angle, position: position, speed: speed)
  ///      }
  ///    }
  ///    playfield.wrapCoordinates()
  ///    ...
  ///    endOfUpdate()
  ///  }
  /// ```
  ///
  /// Be sure to call `super.update` at the start of the subclass's method, and to
  /// call `endOfUpdate` at the end of it so that the point of interest marking for
  /// the render loop will be handled.
  override func update(_ currentTime: TimeInterval) {
    os_signpost(.begin, log: .poi, name: "1_update", signpostID: signpostID)
    super.update(currentTime)
    Globals.lastUpdateTime = currentTime
    // Start the entry transition if needed
    doEntryTransition()
  }

  /// Mark the end of the update phase and the start of actions
  func endOfUpdate() {
    os_signpost(.end, log: .poi, name: "1_update", signpostID: signpostID)
    os_signpost(.begin, log: .poi, name: "2_actions", signpostID: signpostID)
  }

  /// Mark the end of actions and the start of physics computations
  override func didEvaluateActions() {
    os_signpost(.end, log: .poi, name: "2_actions", signpostID: signpostID)
    os_signpost(.begin, log: .poi, name: "3_physics", signpostID: signpostID)
  }

  /// Mark the end of the render loop
  override func didFinishUpdate() {
    os_signpost(.end, log: .poi, name: "3_physics", signpostID: signpostID)
  }
}
