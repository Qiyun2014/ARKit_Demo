//
//  DYARView.m
//  iOS11_proj
//
//  Created by IYNMac on 29/9/17.
//  Copyright © 2017年 IYNMac. All rights reserved.
//
#if __has_include(<ARKit/ARKit.h>)
#import "DYARView.h"
#import <ARKit/ARKit.h>

static NSString *ar_ball_name = @"ball";
static NSString *ar_animation_key = @"dancing";

@interface DYARView () <ARSCNViewDelegate, ARSessionDelegate, CAAnimationDelegate, SCNPhysicsContactDelegate>

@property (nonatomic, strong) ARSCNView *sceneView;
@property (nonatomic, strong) SCNNode *contentNode;
@property (nonatomic, strong) NSMutableDictionary  *planes;


@end

@implementation DYARView{
    
    CADisplayLink   *_displayLink;
    CGFloat          _scale;
    CGColorSpaceRef             _rgbColorSpace;
    CVPixelBufferPoolRef        _outputBufferPool;
    
    DYARManNode     *_mainNode;
    //DYARBallNode    *_ballNode;
    NSString        *_scnassetsOfHeadPath;
}

- (id)initWithFrame:(CGRect)frame{
    
    if (self == [super initWithFrame:frame]) {
        
        _scale = [[UIScreen mainScreen] scale];
        self.planes = [NSMutableDictionary dictionary];
        
        [self addBottomPlaneWithContactDetect];
        [self addGestureRecognizerEvents];
        [self addSubview:self.sceneView];
    }
    return self;
}

- (void)dealloc{
    
    [self.sceneView.scene setPaused:YES];
    [self.sceneView.session pause];
    
    [self.sceneView.scene.rootNode removeFromParentNode];
    [self.sceneView.scene removeAllParticleSystems];
    [self.sceneView removeFromSuperview];
    [self.contentNode removeFromParentNode];
    
    self.sceneView = nil;
    self.contentNode = nil;
}

- (void)layoutSubviews{
    self.sceneView.frame = self.bounds;
    [super layoutSubviews];
}

// Dragon_2.5_For_Animations
- (SCNNode *)createNodeWithName:(NSString *)name fileType:(NSString *)type{
    
    self.contentNode = [SCNNode node];
    _mainNode = [[DYARManNode alloc] initWithNamed:[NSString stringWithFormat:@"%@/%@",_scnassetsOfHeadPath,name]];
    //_ballNode = [[DYARBallNode alloc] initWithNode];
    
    [self.contentNode addChildNode:_mainNode];
    //[self.contentNode addChildNode:_ballNode];
    
    return self.contentNode;
}

#pragma mark    -   private method

- (void)addGestureRecognizerEvents{
    
    // add gesture recognizer to sceneview
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                          action:@selector(didPan:)];
    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                action:@selector(didDoubleTap:)];
    doubleTap.numberOfTapsRequired = 2;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                          action:@selector(didTap:)];
    tap.numberOfTapsRequired = 1;
    [tap requireGestureRecognizerToFail:doubleTap];
    UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self
                                                                                action:@selector(didPinch:)];
    
    [self.sceneView addGestureRecognizer:tap];
    [self.sceneView addGestureRecognizer:doubleTap];
    [self.sceneView addGestureRecognizer:pan];
    [self.sceneView addGestureRecognizer:pinch];
}

- (void)addBottomPlaneWithContactDetect{
    
    // For our physics interactions, we place a large node a couple of meters below the world origin, after an explosion, if the geometry we added has fallen onto this surface which is place way below all of the surfaces we would have detected via ARKit then we consider this geometry to have fallen out of the world and remove it
    SCNBox *bottomPlane = [SCNBox boxWithWidth:1000 height:0.5 length:1000 chamferRadius:0];
    SCNMaterial *bottomMaterial = [SCNMaterial new];
    bottomMaterial.diffuse.contents = [UIColor colorWithWhite:1.0 alpha:.0f];
    bottomPlane.materials = @[bottomMaterial];
    
    // Create the bottom node
    SCNNode *bottomNode = [SCNNode nodeWithGeometry:bottomPlane];
    bottomNode.position = SCNVector3Make(0, -10, 0);
    bottomNode.physicsBody = [SCNPhysicsBody bodyWithType:SCNPhysicsBodyTypeKinematic shape:nil];
    bottomNode.physicsBody.categoryBitMask = DYARNodeDetectionMaskCategoryBottom;
    bottomNode.physicsBody.contactTestBitMask = DYARNodeDetectionMaskCategoryCube;
    
    // Add bottom node, observer the bottom contact
    [self.sceneView.scene.rootNode addChildNode:bottomNode];
    self.sceneView.scene.physicsWorld.contactDelegate = self;
}

- (void)insertGeometry:(ARHitTestResult *)hitResult {
    // Right now we just insert a simple cube, later we will improve these to be more
    // interesting and have better texture and shading
    
    float dimension = 0.1;
    SCNBox *cube = [SCNBox boxWithWidth:dimension height:dimension length:dimension chamferRadius:0];
    cube.chamferRadius = 0.5f;

    SCNNode *node = [SCNNode nodeWithGeometry:cube];
    int R = (arc4random() % 256) ;
    int G = (arc4random() % 256) ;
    int B = (arc4random() % 256) ;
    ///float A = (arc4random() % 10)/10.0;
    node.geometry.firstMaterial.diffuse.contents = [UIColor colorWithRed:R/255.0 green:G/255.0 blue:B/255.0 alpha:1.0];
    
    // The physicsBody tells SceneKit this geometry should be manipulated by the physics engine
    node.physicsBody = [SCNPhysicsBody bodyWithType:SCNPhysicsBodyTypeDynamic shape:nil];
    node.physicsBody.mass = 1.0;
    node.physicsBody.categoryBitMask = DYARNodeDetectionMaskCategoryCube;
    
    // We insert the geometry slightly above the point the user tapped, so that it drops onto the plane
    // using the physics engine
    float insertionYOffset = 1.5;
    node.position = SCNVector3Make(
                                   hitResult.worldTransform.columns[3].x,
                                   hitResult.worldTransform.columns[3].y + insertionYOffset,
                                   hitResult.worldTransform.columns[3].z
                                   );
    
    //SCNParticleSystem *particles = [self asc_loadParticleSystemsNamed:@"sportModel.scnassets/enemy_explosion.scn"];
    //[_sceneView.scene addParticleSystem:particles withTransform:_sceneView.scene.rootNode.worldTransform];
    
    SCNNode *fNode = [self.sceneView.scene.rootNode childNodes].firstObject;
    fNode.scale = SCNVector3Make(2, 2, 2);
    
    [self.sceneView.scene.rootNode addChildNode:node];
}

#pragma mark    -   get method

- (ARSCNView *)sceneView{
    
    if (!_sceneView) {
        _sceneView = [[ARSCNView alloc] initWithFrame:self.bounds];
        
        // Set the view's delegate
        _sceneView.delegate = self;
        
        // Show statistics such as fps and timing information
        _sceneView.showsStatistics = YES;
        _sceneView.automaticallyUpdatesLighting = YES;
        _sceneView.autoenablesDefaultLighting = YES;
        //_sceneView.scene = [self mainScene];
        //_sceneView.debugOptions =   ARSCNDebugOptionShowWorldOrigin | ARSCNDebugOptionShowFeaturePoints;
        
        // Create a session configuration
        ARWorldTrackingConfiguration *configuration = [[ARWorldTrackingConfiguration alloc] init];
        configuration.planeDetection = ARPlaneDetectionHorizontal;
        
        // Run the view's session
        [_sceneView.session runWithConfiguration:configuration options:ARSessionRunOptionResetTracking | ARSessionRunOptionRemoveExistingAnchors];
        
        // Add session delegate
        //_sceneView.session.delegate = self;
        
        // Add contact delegate
        _sceneView.scene.physicsWorld.contactDelegate = self;
    }
    return _sceneView;
}

- (SCNScene *)mainScene{
    SCNScene *scene = [SCNScene sceneNamed:@"sportModel.scnassets/main.scn"];
    return scene;
}

- (NSArray *)ar_allAnimations{
    
    switch (_modelType) {
        case DYARModelTypeSports:
            return @[@"sportModel.scnassets/3d_model/1-1/Goalkeeper Diving Save",
                     @"sportModel.scnassets/3d_model/1-1/Northern Soul Spin",
                     @"sportModel.scnassets/3d_model/1-1/Shoved Reaction With Spin",
                     @"sportModel.scnassets/3d_model/1-1/Goalkeeper Overhand Throw"
                     ];
            break;
        
        case DYARModelTypeDance:
            return @[@"sportModel.scnassets/3d_model/2-1/Knee Jabs To Uppercut",
                     @"sportModel.scnassets/3d_model/2-1/Catwalk Walk Start Turn 180 Left",
                     @"sportModel.scnassets/3d_model/2-1/Push Up",
                     @"sportModel.scnassets/3d_model/2-1/Baseball Step Out"
                     ];
            break;
            
        default:
            break;
    }
    return nil;
}

#pragma mark    -   set

- (void)setModelType:(DYARModelType)modelType{
    
    _modelType = modelType;
    NSString *baseModelWithName;
    
    switch (modelType) {
        case DYARModelTypeUnknow:
            baseModelWithName = nil;
            break;
            
        case DYARModelTypeDance:
            baseModelWithName = kARNodeName_dance;
            _scnassetsOfHeadPath = @"sportModel.scnassets/3d_model/2-1";
            break;
            
        case DYARModelTypeSports:
            baseModelWithName = kARNodeName_sport;
            _scnassetsOfHeadPath = @"sportModel.scnassets/3d_model/1-1";
            break;
            
        default:
            break;
    }
    
    [self updateSceneWithName:baseModelWithName withAnimation:[SCNAction new]];
}

- (void)setParticleType:(DYARParticleType)particleType{
    
    if (_planes.count <= 0 || particleType == _particleType) return;
    
    // Get first plane, this is DYARPlane class
    NSString *firstKey = self.planes.allKeys.firstObject;
    DYARPlane *plane = (DYARPlane *)[self.planes objectForKey:firstKey];
    if (!plane) {
        return;
    }
    
    // Remove all particle systems of the receiver.
    [plane removeAllParticleSystems];

    _particleType = particleType;
    switch (_particleType) {

        // Add rain particle scene
        case DYARParticleTypeRain:
        {
            SCNParticleSystem *ps = [SCNParticleSystem particleSystemNamed:@"rain" inDirectory:nil];
            SCNParticleSystem *pss = [SCNParticleSystem particleSystemNamed:@"plok" inDirectory:nil];
            pss.idleDuration = 0;
            pss.loops = NO;
            [ps setSystemSpawnedOnCollision:pss];
            [plane addParticleSystem:ps];
        }
            break;
            
        // Add snow particle scene
        case DYARParticleTypeSnow:
        {
            SCNParticleSystem *particleSystem = [SCNParticleSystem particleSystemNamed:@"snow" inDirectory:nil];
            particleSystem.affectedByPhysicsFields = YES;
            [plane addParticleSystem:particleSystem];
        }
            break;
            
        case DYARParticleTypeBomb:
        {
            SCNParticleSystem *particleSystem = [SCNParticleSystem particleSystemNamed:@"Bomb" inDirectory:nil];
            particleSystem.local = YES;
            particleSystem.particleIntensityVariation = 1.0f;
            [plane addParticleSystem:particleSystem];
        }
            break;
            
        default:
            break;
    }
}

- (NSString *)ratherNodeWithName:(NSString *)aName{

    NSString *str1 = @"sportModel.scnassets/3d_model/2-1";
    NSString *str2 = @"sportModel.scnassets/3d_model/1-1";
    
    if ([aName isEqualToString:str1]) {
        return str2;
    }else
        return str1;
}

#pragma mark    -   GestureRecognizer

- (void)didTap:(UITapGestureRecognizer *)tap{
    
    CGPoint point = [tap locationInView:self.sceneView];
    NSArray *results = [self.sceneView hitTest:point options:@{SCNHitTestBoundingBoxOnlyKey : @YES}];
    SCNHitTestResult *aResult = results.firstObject;
    NSArray<ARHitTestResult *> *result = [self.sceneView hitTest:point types:ARHitTestResultTypeExistingPlaneUsingExtent];
    
    // If the intersection ray passes through any plane geometry they will be returned, with the planes
    // ordered by distance from the camera
    if (result.count == 0) {
        
        result = [self.sceneView hitTest:point types:ARHitTestResultTypeExistingPlane | ARHitTestResultTypeFeaturePoint];
        ARHitTestResult * hitResult = [result firstObject];
        SCNText *text = [SCNText textWithString:@"斗鱼TV" extrusionDepth:0.01];
        SCNNode *textNode = [SCNNode nodeWithGeometry:text];
        text.font = [UIFont systemFontOfSize:0.15];
        textNode.geometry.firstMaterial.diffuse.contents = [UIColor redColor];
        SCNNode *rootNode = self.sceneView.scene.rootNode;
        textNode.worldPosition = SCNVector3Make(hitResult.worldTransform.columns[3].x, hitResult.worldTransform.columns[3].y, hitResult.worldTransform.columns[3].z);
        [rootNode addChildNode:textNode];
        
        return;
    }
    
    // If there are multiple hits, just pick the closest plane
    ARHitTestResult * hitResult = [result firstObject];
    [self insertGeometry:hitResult];
    
    // Add particle to plane
    [self setParticleType:DYARParticleTypeSnow];

#if 0
    if (aResult) {
        if ([aResult.node.name isEqualToString:@"Solid_001"]) {

            SCNNode *rootNode = self.sceneView.scene.rootNode;
            NSLog(@"root node = %@",rootNode);
            GLKVector3 c = SCNVector3ToGLKVector3(rootNode.childNodes.firstObject.worldPosition);
            GLKVector3 p = SCNVector3ToGLKVector3(aResult.node.worldPosition);
            GLKVector3 dir = GLKVector3Subtract(c, p);
            SCNAction *action_y = [SCNAction moveTo:SCNVector3FromGLKVector3(dir) duration:5];
            SCNAction *action_x = [SCNAction rotateByX:0 y:0 z:-M_PI * 5 duration:5];
            SCNAction *group = [SCNAction group:@[action_y, action_x/*, [SCNAction waitForDuration:2], [SCNAction fadeOutWithDuration:0.5], [SCNAction removeFromParentNode]*/]];
            group.timingMode = SCNActionTimingModeEaseInEaseOut;
            [aResult.node runAction:group completionHandler:^{
                NSLog(@"move completed ... ");
                //[self updateNodeAnimation:aResult.node.parentNode animationNamed:[self ar_allAnimations][3] withRepeatCount:1];
            }];
        }else{
            [self updateNodeAnimation:aResult.node.parentNode animationNamed:[self ar_allAnimations][0] withRepeatCount:1];
        }
        SCNNode *currentNode = aResult.node;
        NSLog(@"currentNode = %@",currentNode);
        NSLog(@"单机  添加动画...");
    }
#endif
}

- (void)didDoubleTap:(UITapGestureRecognizer *)tap{
    CGPoint point = [tap locationInView:self.sceneView];
    NSArray *results = [self.sceneView hitTest:point options:nil];
    SCNHitTestResult *aResult = results.firstObject;
    if (aResult) {
        
        [self updateNodeAnimation:aResult.node.parentNode animationNamed:[self ar_allAnimations][1] withRepeatCount:1];
        NSLog(@"双击  添加动画...");
    }
}

- (void)didPan:(UIPanGestureRecognizer *)pan{
    
    CGPoint point = [pan locationInView:self.sceneView];
    NSArray *results = [self.sceneView hitTest:point options:nil];
    SCNHitTestResult *aResult = results.firstObject;
    if (aResult) {
       // simd_float4x4 transform = matrix_identity_float4x4;
       // transform.columns[3].z = -1.5;
       // [aResult.node setSimdTransform:matrix_multiply(self.sceneView.session.currentFrame.camera.transform, transform)];
       // aResult.node.position = [self.sceneView unprojectPoint:SCNVector3Make(point.x, point.y, -1.5)];
        [self updateNodeAnimation:aResult.node.parentNode animationNamed:[self ar_allAnimations][2] withRepeatCount:1];
        NSLog(@"移动  添加动画...");
    }
}

- (void)didPinch:(UIPinchGestureRecognizer *)pinch{
    
    CGPoint point = [pinch locationInView:self.sceneView];
    NSArray *results = [self.sceneView hitTest:point options:nil];
    SCNHitTestResult *aResult = results.firstObject;
    if (aResult) {
        [aResult.node.parentNode removeFromParentNode];
        aResult.node.parentNode.geometry.firstMaterial.normal.contents = nil;
        aResult.node.parentNode.geometry.firstMaterial.diffuse.contents = nil;
        aResult.node.parentNode.parentNode.geometry = nil;
        NSLog(@"删除...");
        _particleType = DYARParticleTypeUnknow;
    }
}


#pragma mark    -   ARSCNViewDelegate

/**
 Called when a node will be updated with data from the given anchor.
 
 @param renderer The renderer that will render the scene.
 @param node The node that will be updated.
 @param anchor The anchor that was updated.
 */
- (void)renderer:(id<SCNSceneRenderer>)renderer willUpdateNode:(SCNNode *)node forAnchor:(ARAnchor *)anchor{
    
    // 物体位置相对相机的距离  进行移动
    // matrix_float4x4 transform = self.sceneView.session.currentFrame.camera.transform;
    
    NSLog(@"will update node.... world position = %@", NSStringFromGLKVector3(GLKVector3Make(self.sceneView.scene.rootNode.worldPosition.x, self.sceneView.scene.rootNode.worldPosition.y, self.sceneView.scene.rootNode.worldPosition.z)));
}

/**
 Called when a new node has been mapped to the given anchor.
 
 @param renderer The renderer that will render the scene.
 @param node The node that maps to the anchor.
 @param anchor The added anchor.
 */
- (void)renderer:(id<SCNSceneRenderer>)renderer didAddNode:(SCNNode *)node forAnchor:(ARAnchor *)anchor{
    
    NSLog(@"current node sum =  %lu",renderer.scene.rootNode.childNodes.count);
    if ([anchor isKindOfClass:[ARPlaneAnchor class]]) {
        
        DYARPlane *plane = [[DYARPlane alloc] initWithPlaneAnchor:(ARPlaneAnchor *)anchor isHidden:NO];
        [_planes setValue:plane forKey:anchor.identifier.UUIDString];
        [node addChildNode:plane];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            SCNNode *newNode = [self.contentNode clone];
            [node.childNodes enumerateObjectsUsingBlock:^(SCNNode * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if ([obj.name isEqualToString:@"man"]) {
                    [obj.parentNode removeAllActions];
                    [obj.parentNode removeFromParentNode];
                }
            }];
            
            newNode.position = SCNVector3Zero;
            [node addChildNode:newNode];
            
            if (self.startAction) {
                [newNode runAction:self.startAction];
            }
            NSLog(@"all node = %@",self.contentNode.childNodes);
        });
    }
}

/**
 Called when a node has been updated with data from the given anchor.
 */
- (void)renderer:(id <SCNSceneRenderer>)renderer didUpdateNode:(SCNNode *)node forAnchor:(ARAnchor *)anchor {

    DYARPlane *plane = [self.self.planes objectForKey:anchor.identifier.UUIDString];
    if (plane == nil && ![[node.childNodes firstObject] isKindOfClass:[DYARPlane class]]) {
        return;
    }
    
    // When an anchor is updated we need to also update our 3D geometry too. For example
    // the width and height of the plane detection may have changed so we need to update
    // our SceneKit geometry to match that
    [plane updatePlaneAnchor:(ARPlaneAnchor *)anchor];
}

/**
 Called when a mapped node has been removed from the scene graph for the given anchor.
 */
- (void)renderer:(id <SCNSceneRenderer>)renderer didRemoveNode:(SCNNode *)node forAnchor:(ARAnchor *)anchor {
    // Nodes will be removed if planes multiple individual planes that are detected to all be
    // part of a larger plane are merged.
    [_planes removeObjectForKey:anchor.identifier.UUIDString];
}


#pragma mark -  ARSessionDelegate

//会话位置更新（监听相机的移动），此代理方法会调用非常频繁，只要相机移动就会调用，如果相机移动过快，会有一定的误差，具体的需要强大的算法去优化，笔者这里就不深入了
- (void)session:(ARSession *)session didUpdateFrame:(ARFrame *)frame{
    //NSLog(@"相机移动");
    // Retrive the matrix from ARKit - ARFrame - camera.
    //[self.contentNode setTransform:SCNMatrix4FromMat4(frame.camera.transform)];
}

- (void)session:(ARSession *)session didAddAnchors:(NSArray<ARAnchor*>*)anchors{
    NSLog(@"add anchor ...");
}


- (void)session:(ARSession *)session didUpdateAnchors:(NSArray<ARAnchor*>*)anchors{
    NSLog(@"update anchor ...");
}


- (void)session:(ARSession *)session didRemoveAnchors:(NSArray<ARAnchor*>*)anchors{
    NSLog(@"remove anchor ...");
}

#pragma mark    -   SCNPhysicsContactDelegate

- (void)physicsWorld:(SCNPhysicsWorld *)world didBeginContact:(SCNPhysicsContact *)contact{
    
    NSLog(@"begin contact ...");
    DYARNodeDetectionMask contactMask = contact.nodeA.physicsBody.categoryBitMask | contact.nodeB.physicsBody.categoryBitMask;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (contactMask == (DYARNodeDetectionMaskCategoryBottom | DYARNodeDetectionMaskCategoryCube)) {
            if (contact.nodeA.physicsBody.categoryBitMask == DYARNodeDetectionMaskCategoryBottom) {
                SCNParticleSystem *particleSystem = [SCNParticleSystem particleSystemNamed:@"Reactor" inDirectory:nil];
                SCNNode *systemNode = [SCNNode node];
                [systemNode addParticleSystem:particleSystem];
                systemNode.position = contact.nodeA.position;
                [self.sceneView.scene.rootNode addChildNode:systemNode];
                [contact.nodeB removeFromParentNode];
            } else {
                [contact.nodeA removeFromParentNode];
            }
        }
    });
}

- (void)physicsWorld:(SCNPhysicsWorld *)world didUpdateContact:(SCNPhysicsContact *)contact{
    
    /*
    //get an node
    SCNNode *nodeA = contact.nodeA;
    SCNNode *nodeB = contact.nodeB;
    
    SCNVector3 contactPoint = contact.contactPoint;
    
    if(nodeA.physicsBody.categoryBitMask == DYARNodeDetectionMaskBall){
        NSLog(@"do something...");
    }
     */
}

- (void)physicsWorld:(SCNPhysicsWorld *)world didEndContact:(SCNPhysicsContact *)contact{
    NSLog(@"end contact ...");
}

#pragma mark    -   private or public method

- (void)updateSceneWithName:(NSString *)name withAnimation:(SCNAction *)action{
    
    self.startAction = action;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [_mainNode.parentNode removeFromParentNode];
        _mainNode = nil;
        
        [self.sceneView.scene.rootNode.parentNode removeFromParentNode];
        [self.sceneView.scene removeAllParticleSystems];
        [self.contentNode.parentNode removeFromParentNode];
        [self createNodeWithName:name fileType:ARNodeFormat];
    });
}

- (void)updateNodeAnimation:(SCNNode *)node animationNamed:(NSString *)animationNamed withRepeatCount:(int)repeatCount{
    
    if (_mainNode) {
        [_mainNode loadAnimationWithSceneName:animationNamed];
        CAAnimation *animation = [_mainNode.animation valueForKey:ar_animation_key];
        if (repeatCount) animation.repeatCount = repeatCount;
        animation.delegate = self;
        [node addAnimation:animation forKey:ar_animation_key];
        //[aResult.node.parentNode addAnimation:animation forKey:@"dancing"];
        
        [node removeAllAudioPlayers];
        NSURL *audioURL = [NSURL URLWithString:[[NSBundle mainBundle] pathForResource:@"rail_wood_loop" ofType:@".mp3"]];
        SCNAudioSource *audioSource = [[SCNAudioSource alloc] initWithURL:audioURL];
        audioSource.rate = 2;
        [node runAction:[SCNAction playAudioSource:audioSource waitForCompletion:NO]];
    }
}

- (SCNParticleSystem *)asc_loadParticleSystemsNamed:(nullable NSString *)name{
    
    return [self loadParticleSystemsAtPath:name];
}

- (SCNParticleSystem *)loadParticleSystemsAtPath:(NSString *)path{
    
    NSString *directory = [path stringByDeletingLastPathComponent];
    NSString *fileName = [path lastPathComponent];
    NSString *ext = [path pathExtension];
    if([ext isEqualToString:@"scnp"]){
        return [SCNParticleSystem particleSystemNamed:fileName inDirectory:directory];
    }
    else{
        NSMutableArray *particles = [NSMutableArray array];
        SCNScene *scene = [SCNScene sceneNamed:fileName inDirectory:directory options:nil];
        [scene.rootNode enumerateHierarchyUsingBlock:^(SCNNode * _Nonnull node, BOOL * _Nonnull stop) {
            if(node.particleSystems){
                [particles addObjectsFromArray:node.particleSystems];
            }
        }];
        return particles.firstObject;
    }
    
    return nil;
}


#pragma mark    -   CAAnimationDelegate

/* Called when the animation begins its active duration. */
- (void)animationDidStart:(CAAnimation *)anim{

    NSLog(@"开始动画  ...");
}

/* Called when the animation either completes its active duration or
 * is removed from the object it is attached to (i.e. the layer). 'flag'
 * is true if the animation reached the end of its active duration
 * without being removed. */
- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag{
    
    SCNNode *ballNode = [self.sceneView.scene.rootNode childNodeWithName:ar_ball_name recursively:YES];
    [ballNode runAction:[SCNAction rotateByX:0 y:0 z:3 duration:3]];
    
    NSLog(@"结束动画  ...");
}

@end

#pragma mark    ----------------------------------------------------------------------------
#pragma mark    DYARViewCapture

@implementation DYARView(DYARViewCapture)

#pragma mark    -   set method
- (void)setRecordType:(DYARRecordType)recordType{
    
    switch (recordType) {
        case DYARRecordTypeStart: {
            if (!_displayLink) {
                _rgbColorSpace = CGColorSpaceCreateDeviceRGB();
                NSDictionary *bufferAttributes = @{(id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA),
                                                   (id)kCVPixelBufferCGBitmapContextCompatibilityKey : @YES,
                                                   (id)kCVPixelBufferWidthKey : @(CGRectGetWidth(self.frame) * _scale),
                                                   (id)kCVPixelBufferHeightKey : @(CGRectGetHeight(self.frame) * _scale),
                                                   (id)kCVPixelBufferBytesPerRowAlignmentKey : @(CGRectGetWidth(self.frame) * _scale * 4)
                                                   };
                _outputBufferPool = NULL;
                CVPixelBufferPoolCreate(NULL, NULL, (__bridge CFDictionaryRef)(bufferAttributes), &_outputBufferPool);
                _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayPixelBuffer:)];
                [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
                _displayLink.preferredFramesPerSecond = 20;
            }
            [_displayLink setPaused:NO];
        }
            break;
            
        case DYARRecordTypePause: {
            [_displayLink setPaused:YES];
            
        }
            break;
            
        case DYARRecordTypeResume: {
            [_displayLink setPaused:NO];
        }
            break;
            
        case DYARRecordTypeStop: {
            if (_displayLink) {
                [_displayLink removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
                [_displayLink invalidate];
                _displayLink = nil;
                CVPixelBufferPoolRelease(_outputBufferPool);
                CGColorSpaceRelease(_rgbColorSpace);
            }
        }
            break;
            
        default:
            break;
    }
}


- (void)displayPixelBuffer:(CADisplayLink *)displayLink{
    
    if (self.recordDelegate && [self.recordDelegate respondsToSelector:@selector(willOuputVideoPixelBuffer:)]) {
        
        CVPixelBufferRef pixelBuffer = NULL;
        CGContextRef bitmapContext = [self createPixelBufferAndBitmapContext:&pixelBuffer];
        UIGraphicsPushContext(bitmapContext);
        [self drawViewHierarchyInRect:CGRectMake(0, 0, self.sceneView.bounds.size.width, self.sceneView.bounds.size.height) afterScreenUpdates:NO];
        UIGraphicsPopContext();
        [self.recordDelegate willOuputVideoPixelBuffer:pixelBuffer];
        //NSLog(@"time = %@,  current pixel buffer is %@", [[NSDate date] description], @""/*pixelBuffer*/);
        CGContextRelease(bitmapContext);
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        CVPixelBufferRelease(pixelBuffer);
    }
}

// create contextRef associate with pixelBuffer
- (CGContextRef)createPixelBufferAndBitmapContext:(CVPixelBufferRef *)pixelBuffer
{
    CVPixelBufferPoolCreatePixelBuffer(NULL, _outputBufferPool, pixelBuffer);
    CVPixelBufferLockBaseAddress(*pixelBuffer, 0);
    
    CGContextRef bitmapContext = NULL;
    bitmapContext = CGBitmapContextCreate(CVPixelBufferGetBaseAddress(*pixelBuffer),
                                          CVPixelBufferGetWidth(*pixelBuffer),
                                          CVPixelBufferGetHeight(*pixelBuffer),
                                          8,
                                          CVPixelBufferGetBytesPerRow(*pixelBuffer),
                                          _rgbColorSpace,
                                          kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst
                                          );
    CGContextScaleCTM(bitmapContext, _scale, _scale);
    CGAffineTransform flipVertical = CGAffineTransformMake(1, 0, 0, -1, 0, self.sceneView.bounds.size.height);
    CGContextConcatCTM(bitmapContext, flipVertical);
    
    return bitmapContext;
}

@end

#pragma mark    ----------------------------------------------------------------------------
#pragma mark    DYARAdditions

@implementation SCNNode(DYARAdditions)

- (SCNNode *)asc_addChildNodeNamed:(nullable NSString *)name fromSceneNamed:(NSString *)path withScale:(CGFloat)scale {
    // Load the scene from the specified file
    SCNScene *scene = [SCNScene sceneNamed:path inDirectory:nil options:nil];
    
    // Retrieve the root node
    SCNNode *node = scene.rootNode;
    
    // Search for the node named "name"
    if (name) {
        node = [node childNodeWithName:name recursively:YES];
    }
    else {
        // Take the first child if no name is passed
        node = node.childNodes[0];
    }
    
    if (scale != 0) {
        // Rescale based on the current bounding box and the desired scale
        // Align the node to 0 on the Y axis
        SCNVector3 min, max;
        [node getBoundingBoxMin:&min max:&max];
        
        GLKVector3 mid = GLKVector3Add(SCNVector3ToGLKVector3(min), SCNVector3ToGLKVector3(max));
        mid = GLKVector3MultiplyScalar(mid, 0.5);
        mid.y = min.y; // Align on bottom
        
        GLKVector3 size = GLKVector3Subtract(SCNVector3ToGLKVector3(max), SCNVector3ToGLKVector3(min));
        CGFloat maxSize = MAX(MAX(size.x, size.y), size.z);
        
        scale = scale / maxSize;
        mid = GLKVector3MultiplyScalar(mid, scale);
        mid = GLKVector3Negate(mid);
        
        node.scale = SCNVector3Make(scale, scale, scale);
        node.position = SCNVector3FromGLKVector3(mid);
    }
    
    // Add to the container passed in argument
    [self addChildNode:node];
    
    return node;
}

@end


#pragma mark    ----------------------------------------------------------------------------
#pragma mark    DYARManNode

@implementation DYARManNode

- (id)initWithNamed:(NSString *)named{
    
    if (self == [super init]) {
        
        self.animation = [SCNAnimation new];
        
        SCNScene *scene = [SCNScene sceneNamed:named];
        [scene.rootNode.childNodes enumerateObjectsUsingBlock:^(SCNNode * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (obj) [self addChildNode:obj];
        }];
        
        self.position = SCNVector3Make(0.2, 0.5, 0);         // set node position
        self.scale = SCNVector3Make(0.003, 0.003, 0.003);   // set node scale
        self.physicsBody = [SCNPhysicsBody staticBody];    // add dynamic
        self.light = [SCNLight light];
        self.light.castsShadow = YES;
        self.light.type = SCNLightTypeOmni;
        self.light.color = [UIColor whiteColor];
        self.name = @"man";
        
        // add contact detect
        self.physicsBody.categoryBitMask = DYARNodeDetectionMaskBall;
        self.physicsBody.collisionBitMask = DYARNodeDetectionMaskBall;
        self.physicsBody.contactTestBitMask = DYARNodeDetectionMaskBall;
    }
    return self;
}

- (SCNAnimation *)loadAnimationWithSceneName:(NSString *)sceneName{
    
    SCNAnimation *animation = [self loadAnimationWithKey:ar_animation_key sceneName:sceneName];
    if (!animation) {
        return nil;
    }
    return animation;
}

- (SCNAnimation *)loadAnimationWithKey:(NSString *)key sceneName:(NSString *)sceneName{
    
    NSString *scenePath = [[NSBundle mainBundle] pathForResource:sceneName ofType:ARNodeFormat];
    if (!scenePath) {
        NSLog(@"Load Animation faild...");
        return nil;
    }
    SCNSceneSource *sceneSource = [SCNSceneSource sceneSourceWithURL:[NSURL fileURLWithPath:scenePath] options:nil];
    // get animation ids
    NSArray *animationIDs =  [sceneSource identifiersOfEntriesWithClass:[CAAnimation class]];
    //NSLog(@"animationIDs = %@",animationIDs);
    
    NSString *identifier = animationIDs.firstObject;
    CAAnimation *animation = [sceneSource entryWithIdentifier:identifier withClass:[CAAnimation class]];
    if (animation) {
        animation.repeatCount = 1;
        animation.fadeInDuration = 1.0;     // 1.0
        animation.fadeOutDuration = .5f;    // .5
        [self.animation setValue:animation forKey:key];
        return (SCNAnimation *)animation;
    }else{
        //animation = (CAAnimation *)[self animationFromSceneNamed:scenePath];
        if (!animation) {
            SCNNode *cNode = [self asc_addChildNodeNamed:@"bossGroup" fromSceneNamed:sceneName withScale:0.0];
            SCNNode *nNode = [cNode childNodeWithName:@"arissa_Hips" recursively:YES];
            
            for (NSString *animationKey in nNode.animationKeys) {
                // Find all the animations. Make them system time based and repeat forever.
                // And finally replace the old animation.
                animation = [CAAnimation animationWithSCNAnimation:[nNode animationPlayerForKey:animationKey].animation];
                animation.usesSceneTimeBase = NO;
                animation.repeatCount = FLT_MAX;
            }
            [cNode removeFromParentNode];
            [nNode removeFromParentNode];
        }
        
        [self.animation setValue:animation forKey:key];
        return (SCNAnimation *)animation;
    }
    return nil;
}

- (SCNAnimation *)animationFromSceneNamed:(NSString *)path {
    SCNScene *scene = [SCNScene sceneNamed:path];
    __block SCNAnimation *animation = nil;
    
    [scene.rootNode enumerateChildNodesUsingBlock:^(SCNNode *child, BOOL *stop) {
        if (child.animationKeys.count > 0) {
            SCNAnimationPlayer *animationPlayer = [child animationPlayerForKey:child.animationKeys[0]];
            animation = animationPlayer.animation;
            *stop = YES;
        }
    }];
    return animation;
}

@end

#pragma mark    ----------------------------------------------------------------------------
#pragma mark    DYARBallNode

@implementation DYARBallNode

static NSString *ar_ball_scnpath = @"sportModel.scnassets/Ball DAE";

- (id)initWithNode{
    
    if (self == [super init]) {
        
        [self asc_addChildNodeNamed:ar_ball_name fromSceneNamed:ar_ball_scnpath withScale:0.1];
        
        // set node position
        self.position = SCNVector3Make(0, 0.4, 0);
        self.rotation = SCNVector4Make(M_PI_2, 0, 0, 0);
        self.name = ar_ball_name;

        // set meterial attribute
        self.physicsBody = [SCNPhysicsBody dynamicBody];
        self.geometry.firstMaterial.multiply.contents = [UIColor darkGrayColor];
        self.light.castsShadow = YES;
        //self.light.color = [UIColor redColor];
        
        // add contact detect
        self.physicsBody.categoryBitMask = DYARNodeDetectionMaskBall;
        self.physicsBody.collisionBitMask = DYARNodeDetectionMaskBall | DYARNodeDetectionMaskCharacter;
        self.physicsBody.contactTestBitMask = DYARNodeDetectionMaskBall | DYARNodeDetectionMaskCharacter;
    }
    return self;
}


@end

#pragma mark    ----------------------------------------------------------------------------
#pragma mark    DYARPlane

@implementation DYARPlane

- (id)initWithPlaneAnchor:(ARPlaneAnchor *)anchor isHidden:(BOOL)hidden{
    
    if (self == [super init]) {
        
        // Using a SCNBox and not SCNPlane to make it easy for the geometry we add to the scene to interact with the plane.
        self.planeAnchor = anchor;
        
        // For the physics engine to work properly give the plane some height so we get interactions
        // between the plane and the gometry we add to the scene
        float planeHeight = 0.01;
        
        self.planeGeometry = [SCNBox boxWithWidth:anchor.extent.x height:anchor.extent.z length:planeHeight chamferRadius:.0f];
        
        // Instead of just visualizing the grid as a gray plane, we will render
        // it in some Tron style colours.
        SCNMaterial *material = [SCNMaterial new];
        UIImage *img = [UIImage imageNamed:@"sportModel.scnassets/tron_grid.png"];
        material.diffuse.contents = img;
        
        // Since we are using a cube, we only want to render the tron grid
        // on the top face, make the other sides transparent
        SCNMaterial *transparentMaterial = [SCNMaterial new];
        transparentMaterial.diffuse.contents = [UIColor colorWithWhite:1.0 alpha:0.0];
        
        if (hidden) {
            self.planeGeometry.materials = @[transparentMaterial, transparentMaterial, transparentMaterial, transparentMaterial, transparentMaterial, transparentMaterial];
        } else {
            self.planeGeometry.materials = @[transparentMaterial, transparentMaterial, transparentMaterial, transparentMaterial, material, transparentMaterial];
        }
        
        SCNNode *planeNode = [SCNNode nodeWithGeometry:self.planeGeometry];
        
        // Since our plane has some height, move it down to be at the actual surface
        planeNode.position = SCNVector3Make(0, -planeHeight / 2, 0);
        
        // Give the plane a physics body so that items we add to the scene interact with it
        planeNode.physicsBody = [SCNPhysicsBody
                                 bodyWithType:SCNPhysicsBodyTypeKinematic
                                 shape: [SCNPhysicsShape shapeWithGeometry:self.planeGeometry options:nil]];
        
        [self setTextureScale];        
        [self addChildNode:planeNode];
    }
    return self;
}

- (void)updatePlaneAnchor:(ARPlaneAnchor *)anchor{
    
    // As the user moves around the extend and location of the plane may be updated. We need to update our 3D geometry to match the new parameters of the plane.
    self.planeGeometry.width = anchor.extent.x;
    self.planeGeometry.length = anchor.extent.z;
    
    // When the plane is first created it's center is 0,0,0 and the nodes transform contains the translation parameters. As the plane is updated the planes translation remains the same but it's center is updated so we need to update the 3D geometry position
    self.position = SCNVector3Make(anchor.center.x, 0, anchor.center.z);
    
    SCNNode *node = [self.childNodes firstObject];
    //self.physicsBody = nil;
    node.physicsBody = [SCNPhysicsBody
                        bodyWithType:SCNPhysicsBodyTypeKinematic
                        shape: [SCNPhysicsShape shapeWithGeometry:self.planeGeometry options:nil]];
    [self setTextureScale];
}

- (void)setTextureScale{
    
    CGFloat width = self.planeGeometry.width;
    CGFloat height = self.planeGeometry.length;
    
    // As the width/height of the plane updates, we want our tron grid material to cover the entire plane, repeating the texture over and over. Also if the grid is less than 1 unit, we don't want to squash the texture to fit, so  scaling updates the texture co-ordinates to crop the texture in that case
    SCNMaterial *material = self.planeGeometry.materials[4];
    material.diffuse.contentsTransform = SCNMatrix4MakeScale(width, height, 1);
    material.diffuse.wrapS = SCNWrapModeRepeat;
    material.diffuse.wrapT = SCNWrapModeRepeat;
}

- (void)hide{
    
    SCNMaterial *transparentMaterial = [SCNMaterial new];
    transparentMaterial.diffuse.contents = [UIColor colorWithWhite:1.0 alpha:0.0];
    self.planeGeometry.materials = @[transparentMaterial, transparentMaterial, transparentMaterial, transparentMaterial, transparentMaterial, transparentMaterial];
}

@end

#endif

