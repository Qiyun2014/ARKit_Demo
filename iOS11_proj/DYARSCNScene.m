//
//  DYARSCNScene.m
//  iOS11_proj
//
//  Created by IYNMac on 25/9/17.
//  Copyright © 2017年 IYNMac. All rights reserved.
//

#import "DYARSCNScene.h"
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "DYARSCNScene+Category.h"

enum RelativeCameraPositionToHead{
    withinFieldOfView = 0,
    needsToTurnLeft,
    neddsToTurnRight,
    tooHighOrLow
};

enum MouthAnimationState {
	mouthClosed,
    mouthMoving,
    shootingTongue,
    pullingBackTongue
};

@implementation DYARSCNScene{
    
    SCNNode *_contentRootNode;
    SCNNode *_geometryRoot;
    SCNNode *_head, *_leftEye, *_rightEye, *_jaw, *_tongueTip, *_focusOfTheHead, *_focusOfLeftEye, *_focusOfRightEye, *_tongueRestPositionNode;
    
    SCNMaterial *_skin;
    
    SCNAnimation *_idleAnimation, *_turnLeftAnimation, *_turnRightAnimation;
    BOOL _modelLoaded, _headIsMoving, _chameleonIsTurning, _didEnterTargetLockDistance;
    simd_float3 _focusNodeBasePosition, _leftEyeTargetOffset, _rightEyeTargetOffset, _currentTonguePosition;
    
    float _relativeTongueStickOutFactor, _lastDistance;
    int _readyToShootCounter, _triggerTurnLeftCounter, _triggerTurnRightCounter, _lastRelativePosition;
    enum MouthAnimationState _mouthAnimationState;
    
    NSTimer *_changeColorTimer;
    SCNVector3 _lastColorFromEnvironment;
}

- (id)init{
    
    if (self == [super init]) {
        
        _lastRelativePosition = 3;
        _mouthAnimationState = mouthClosed;
        _lastColorFromEnvironment = SCNVector3Make(130.0 / 255.0, 196.0 / 255.0, 174.0 / 255.0);
        
        _contentRootNode = [SCNNode node];
        _focusOfTheHead = [SCNNode node];
        _focusOfLeftEye = [SCNNode node];
        _focusOfRightEye = [SCNNode node];
        _tongueRestPositionNode = [SCNNode node];
        
        // Load the environment map
        self.lightingEnvironment.contents = [UIImage imageNamed:@"art.scnassets/environment_blur.exr"];
        [self loadModel];
    }
    return self;
}

- (void)loadModel{
    
    SCNScene *scene = [SCNScene sceneNamed:@"chameleon" inDirectory:@"art.scnassets" options:nil];
    if (!scene) {
        NSLog(@"Load Scene faild");
        return;
    }
    
    SCNNode *wrapperNode = [SCNNode node];
    for (SCNNode *child in scene.rootNode.childNodes){
        [wrapperNode addChildNode:child];
    }
    
    [self.rootNode addChildNode:_contentRootNode];
    [_contentRootNode addChildNode:wrapperNode];
    [self hide];
    
    [self setupSpecialNodes];
    [self setupConstraints];
    [self setupShader];
    [self preloadAnimations];
    [self resetState];
    
    _modelLoaded = YES;
}

#pragma mark    -   animation

- (void)playTurnAnimation:(SCNAnimation *)animation{
    
    float rotationAngle = .0f;
    if (animation == _turnLeftAnimation) {
        rotationAngle = M_PI / 4;
    }else if (animation == _turnRightAnimation){
        rotationAngle = -M_PI / 4;
    }
    
    SCNNode *modelBaseNode = [_contentRootNode childNodes].firstObject;
    [modelBaseNode addAnimation:animation forKey:animation.keyPath];
    
    _chameleonIsTurning = YES;
    [SCNTransaction begin];
    SCNTransaction.animationTimingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    SCNTransaction.animationDuration = animation.duration;
    modelBaseNode.transform = SCNMatrix4Mult(modelBaseNode.presentationNode.transform, SCNMatrix4MakeRotation(rotationAngle, 0, 1, 0));
    [SCNTransaction setCompletionBlock:^{
        _chameleonIsTurning = NO;
    }];
    [SCNTransaction commit];
}

- (enum RelativeCameraPositionToHead)relativePositionToHead:(simd_float3)pointOfViewPosition{
    
    simd_float3 cameraPoslocal = [_head simdConvertPosition:pointOfViewPosition fromNode:nil];
    simd_float3 cameraPosLocalComponentX = simd_make_float3(cameraPoslocal.x, _head.position.y, cameraPoslocal.z);
    float dist = simd_length(cameraPoslocal - _head.simdPosition);
    
    float xAngle = acos(simd_dot(simd_normalize(_head.simdPosition), simd_normalize(cameraPosLocalComponentX))) * 180 /M_PI;
    float yAngle = asin(cameraPoslocal.y / dist) * 180 / M_PI;
    
    float selfToUserDistance = simd_length(pointOfViewPosition - _jaw.simdWorldPosition);
    enum RelativeCameraPositionToHead relativePosition;
    if (yAngle > 60.0) {
        relativePosition = tooHighOrLow;
    }else if (xAngle > 600) {
        relativePosition = (cameraPoslocal.x < 0)?needsToTurnLeft:neddsToTurnRight;
    }else{
        if (selfToUserDistance >= 0 && selfToUserDistance < 0.3) {
            relativePosition = 2;
        }else if ((selfToUserDistance >= 0.3) && (selfToUserDistance < 0.45)){
            if (_lastDistance > 0.45) {
                _didEnterTargetLockDistance = YES;
            }
        }else{
            relativePosition = 0;
        }
    }
    _lastDistance = selfToUserDistance;
    _lastRelativePosition = relativePosition;
    return relativePosition;
}

- (void)openCloseMouthAndShootTongue{
    
    SCNAnimationEvent *startShootEvent = [SCNAnimationEvent animationEventWithKeyTime:0.07 block:^(id<SCNAnimation>  _Nonnull animation, id  _Nonnull animatedObject, BOOL playingBackward) {
        _mouthAnimationState = shootingTongue;
    }];
    
    SCNAnimationEvent *endShootEvent = [SCNAnimationEvent animationEventWithKeyTime:0.65 block:^(id<SCNAnimation>  _Nonnull animation, id  _Nonnull animatedObject, BOOL playingBackward) {
        _mouthAnimationState = pullingBackTongue;
    }];
    
    SCNAnimationEvent *mouthClosedEvent = [SCNAnimationEvent animationEventWithKeyTime:0.99 block:^(id<SCNAnimation>  _Nonnull animation, id  _Nonnull animatedObject, BOOL playingBackward) {
        _mouthAnimationState = mouthClosed;
        _readyToShootCounter = -100;
    }];
    
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"eulerAngles.x"];
    animation.duration = 4.0;
    animation.keyTimes = @[@(.0), @(0.05), @(0.75), @(1.0)];
    animation.values = @[@(.0), @(-0.4), @(-0.4), @(.0)];
    animation.timingFunctions = @[[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut],
                                  [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear],
                                  [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
    animation.animationEvents = @[startShootEvent, endShootEvent, mouthClosedEvent];
    _mouthAnimationState = mouthMoving;
    [_jaw addAnimation:animation forKey:@"open cloas mouth"];
    
    // Move the head a little bit up.
    CAKeyframeAnimation *headUpAnimation = [CAKeyframeAnimation animationWithKeyPath:@"position.y"];
    float startY = _focusOfTheHead.position.y;
    headUpAnimation.duration = 4.0;
    headUpAnimation.keyTimes = @[@(.0), @(0.05), @(0.75), @(1.0)];
    headUpAnimation.values = @[@(startY), @(startY + 0.1), @(startY + 0.1), @(startY)];
    headUpAnimation.timingFunctions = @[[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut],
                                        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear],
                                        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
    [_focusOfTheHead addAnimation:headUpAnimation forKey:@"move head up"];
}

- (void)reactToPositionChange:(ARSCNView *)view{
    [self reactToPlacement:view isInitial:NO];
}

- (void)reactToInitialPlacement:(ARSCNView *)view{
    [self reactToPlacement:view isInitial:YES];
}

- (void)reactToPlacement:(ARSCNView *)sceneView isInitial:(BOOL)isInitial{
    if (isInitial) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self getColorFromEnviroment:sceneView];
            [self activateCamoutFlage:YES];
        });
    }else{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateCamouflage:sceneView];
        });
    }
}

- (void)reactToTap:(ARSCNView *)sceneView{
    
    [self activateCamoutFlage:NO];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self activateCamoutFlage:YES];
    });
}

- (void)activateCamoutFlage:(BOOL)activate{
    
    [_skin setValue:[NSValue valueWithSCNVector3:_lastColorFromEnvironment] forKey:@"skinColorFromEnvironment"];
    
    [SCNTransaction begin];
    [SCNTransaction setAnimationDuration:1.5];
    [_skin setValue:activate?@(1):@(0) forKey:@"blendFactor"];
    [SCNTransaction commit];
}

- (void)updateCamouflage:(ARSCNView *)sceneView{
    
    [self getColorFromEnviroment:sceneView];
    
    [SCNTransaction begin];
    [SCNTransaction setAnimationDuration:1.5];
    [_skin setValue:[NSValue valueWithSCNVector3:_lastColorFromEnvironment] forKey:@"skinColorFromEnvironment"];
    [SCNTransaction commit];
}

- (void)getColorFromEnviroment:(ARSCNView *)sceneView{
    SCNVector3 worldPos = [sceneView projectPoint:_contentRootNode.worldPosition];
    SCNVector3 colorVector = [sceneView averageColorFromEnvironment:worldPos];
    _lastColorFromEnvironment = colorVector;
}


#pragma mark    -   init

- (void)show{
    [_contentRootNode setHidden:NO];
}

- (void)hide{
    [_contentRootNode setHidden:YES];
    [self resetState];
}

- (BOOL)isVisible{
    return !_contentRootNode.isHidden;
}

- (void)setTransform:(simd_float4x4)transform{
    _contentRootNode.simdTransform = transform;
}

- (void)resetState{
    _relativeTongueStickOutFactor = 0;
    _mouthAnimationState = mouthClosed;
    _readyToShootCounter = 0;
    _triggerTurnLeftCounter = 0;
    _triggerTurnRightCounter = 0;
    if (_changeColorTimer) {
        [_changeColorTimer invalidate];
        _changeColorTimer = nil;
    }
}

- (void)setupSpecialNodes{
    
    _geometryRoot = [self.rootNode childNodeWithName:@"Chameleon" recursively:YES];
    _head = [self.rootNode childNodeWithName:@"Neck02" recursively:YES];
    _jaw = [self.rootNode childNodeWithName:@"Jaw" recursively:YES];
    _tongueTip = [self.rootNode childNodeWithName:@"TongueTip_Target" recursively:YES];
    _leftEye = [self.rootNode childNodeWithName:@"Eye_L" recursively:YES];
    _rightEye = [self.rootNode childNodeWithName:@"Eye_R" recursively:YES];
    
    _skin = [[_geometryRoot.geometry materials] firstObject];
    
    // Fix materials
    _geometryRoot.geometry.firstMaterial.lightingModelName = SCNLightingModelPhysicallyBased;
    _geometryRoot.geometry.firstMaterial.roughness.contents = @"art.scnassets/textures/chameleon_ROUGHNESS.png";
    SCNNode *shadowPlane = [self.rootNode childNodeWithName:@"Shadow" recursively:YES];
    shadowPlane.castsShadow = false;
    
    // Set up looking position nodes
    _focusOfTheHead.simdPosition = _focusNodeBasePosition;
    _focusOfLeftEye.simdPosition = _focusNodeBasePosition;
    _focusOfRightEye.simdPosition = _focusNodeBasePosition;
    [_geometryRoot addChildNode:_focusOfTheHead];
    [_geometryRoot addChildNode:_focusOfLeftEye];
    [_geometryRoot addChildNode:_focusOfRightEye];
}

- (void)setupConstraints{
    
    SCNLookAtConstraint *headConstraint = [SCNLookAtConstraint lookAtConstraintWithTarget:_focusOfTheHead];
    [headConstraint setGimbalLockEnabled:YES];
    _head.constraints = @[headConstraint];
    
    SCNLookAtConstraint *leftEyeLookAtConstraint = [SCNLookAtConstraint lookAtConstraintWithTarget:_focusOfLeftEye];
    [leftEyeLookAtConstraint setGimbalLockEnabled:YES];
    
    SCNLookAtConstraint *rightEyeLookAtConstraint = [SCNLookAtConstraint lookAtConstraintWithTarget:_focusOfRightEye];
    [rightEyeLookAtConstraint setGimbalLockEnabled:YES];
    
    SCNTransformConstraint *eyeRotationConstraint = [SCNTransformConstraint transformConstraintInWorldSpace:false withBlock:^SCNMatrix4(SCNNode * _Nonnull node, SCNMatrix4 transform) {
        float eulerX = node.presentationNode.eulerAngles.x;
        float eulerY = node.presentationNode.eulerAngles.y;
        if (eulerX < [self rad:-20]) { eulerX = [self rad:-20]; }
        if (eulerX > [self rad:20]) { eulerX = [self rad:20]; }
        
        if ([node.name isEqualToString:@"Eye_R"]) {
            if (eulerY < [self rad:-150]) { eulerY = [self rad:-150]; }
            if (eulerY > [self rad:-5]) { eulerY = [self rad:-5]; }
        }else{
            if (eulerY > [self rad:150]) { eulerY = [self rad:150]; }
            if (eulerY < [self rad:5]) { eulerY = [self rad:5]; }
        }
        
        SCNNode *tempNode = [SCNNode node];
        tempNode.transform = node.presentationNode.transform;
        tempNode.eulerAngles = SCNVector3Make(eulerX, eulerY, 0);
        return tempNode.transform;
    }];
    
    _leftEye.constraints = @[leftEyeLookAtConstraint, eyeRotationConstraint];
    _rightEye.constraints = @[rightEyeLookAtConstraint, eyeRotationConstraint];
    
    [_tongueTip.parentNode addChildNode:_tongueRestPositionNode];
    _tongueRestPositionNode.transform = _tongueTip.transform;
    _currentTonguePosition = _tongueTip.simdPosition;
}

- (void)setupShader{
    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"skin" ofType:@"shaderModifier" inDirectory:@"art.scnassets"];
    NSError *error;
    NSString *shader = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    if (error) {
        NSLog(@"Load shader faild, error is %@",error);
        return;
    }
    
    _skin.shaderModifiers = @{@"SCNShaderModifierEntryPoint": shader};
    [_skin setValue:@(0) forKey:@"blendFactor"];
    [_skin setValue:[NSValue valueWithSCNVector3:SCNVector3Zero] forKey:@"skinColorFromEnvironment"];
    
    SCNMaterialProperty *sparseTexture = [SCNMaterialProperty materialPropertyWithContents:[UIImage imageNamed:@"art.scnassets/textures/chameleon_DIFFUSE_BASE.png"]];
    [_skin setValue:sparseTexture forKey:@"sparseTexture"];
}

- (void)preloadAnimations{
    
    _idleAnimation = [SCNAnimation animationNamed:@"art.scnassets/anim_idle"];
    _idleAnimation.repeatCount = -1;
    
    _turnLeftAnimation = [SCNAnimation animationNamed:@"art.scnassets/anim_turnleft"];
    _turnLeftAnimation.repeatCount = 1;
    _turnLeftAnimation.blendInDuration = 0.3;
    _turnLeftAnimation.blendOutDuration = 0.3;
    
    _turnRightAnimation = [SCNAnimation animationNamed:@"art.scnassets/anim_turnright"];
    _turnRightAnimation.repeatCount = 1;
    _turnRightAnimation.blendInDuration = 0.3;
    _turnRightAnimation.blendOutDuration = 0.3;
    
    // Start playing idle animation.
    [_contentRootNode.childNodes[0] addAnimation:_idleAnimation forKey:_idleAnimation.keyPath];
    
    [_tongueTip removeAllAnimations];
    [_leftEye removeAllAnimations];
    [_rightEye removeAllAnimations];
    _chameleonIsTurning = NO;
    _headIsMoving = NO;
}

- (float)rad:(float)deg{
    return deg * M_PI / 180;
}

- (void)randomlyUpdate:(inout simd_float3)vector{
    switch (arc4random()%400) {
        case 0:
            vector.x = 0.1;
            break;
        case 1:
            vector.x = -0.1;
            break;
        case 2:
            vector.y = 0.1;
            break;
        case 3:
            vector.y = -0.1;
            break;
        case 4:
        case 5:
        case 6:
        case 7:
            vector = simd_make_float3(0, 0, 0);
            break;
        
        default:
            break;
    }
}


#pragma mark    -   render

- (void)reactToRendering:(ARSCNView *)sceneView{
    
    self.lightingEnvironment.intensity = ((sceneView.session.currentFrame.lightEstimate.ambientIntensity == 0)?1000:sceneView.session.currentFrame.lightEstimate.ambientIntensity) / 100;
    SCNNode *pointOfView = sceneView.pointOfView;
    if (!_modelLoaded || _chameleonIsTurning || !pointOfView) {
        return;
    }
    
    simd_float3 localTarget = [_focusOfTheHead.parentNode simdConvertPosition:pointOfView.simdWorldPosition toNode:nil];
    [self followUserWithEyes:localTarget];
    
    enum RelativeCameraPositionToHead relativePos = [self relativePositionToHead:pointOfView.simdPosition];
    switch (relativePos) {
        case withinFieldOfView:
            [self handleWithinFieldOfView:localTarget distance:0];
            break;
        case needsToTurnLeft:
            [self followUserWithHead:simd_make_float3(0.4, _focusNodeBasePosition.y, _focusNodeBasePosition.z) instantly:false];
            _triggerTurnLeftCounter += 1;
            if (_triggerTurnLeftCounter > 150) {
                _triggerTurnLeftCounter = 0;
                if (_turnLeftAnimation) {
                    [self playTurnAnimation:_turnLeftAnimation];
                }
            }
            break;
        case neddsToTurnRight:
            [self followUserWithHead:simd_make_float3(-0.4, _focusNodeBasePosition.y, _focusNodeBasePosition.z) instantly:false];
            _triggerTurnRightCounter += 1;
            if (_triggerTurnRightCounter > 150) {
                _triggerTurnRightCounter = 0;
                if (_turnRightAnimation) {
                    [self playTurnAnimation:_turnRightAnimation];
                }
            }
            break;
        case tooHighOrLow:
            [self followUserWithEyes:_focusNodeBasePosition];
            break;
            
        default:
            break;
    }
}

- (void)handleWithinFieldOfView:(simd_float3)localTargrt distance:(int)distance{
    
    _triggerTurnLeftCounter = 0;
    _triggerTurnRightCounter = 0;
    switch (distance) {
        case 0:
            [self followUserWithHead:localTargrt instantly:false];
            break;
            
        case 1:
            [self followUserWithHead:localTargrt instantly:!_didEnterTargetLockDistance];
            break;
            
        case 2:
            [self followUserWithHead:localTargrt instantly:YES];
            if (_mouthAnimationState == mouthClosed) {
                _readyToShootCounter += 1;
                if (_readyToShootCounter > 30) {
                    [self openCloseMouthAndShootTongue];
                }
            }else{
                _readyToShootCounter = 0;
            }
            break;
            
        default:
            break;
    }
}

- (void)followUserWithHead:(simd_float3)target instantly:(BOOL)instantly{
    
    if (!_headIsMoving) return;
    
    if (_mouthAnimationState != mouthClosed || instantly) {
        _focusOfTheHead.simdPosition = target;
    }else{
        
        _didEnterTargetLockDistance = NO;
        _headIsMoving = YES;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            SCNAction *action = [SCNAction moveTo:SCNVector3Make(target.x, target.y, target.z) duration:0.5];
            [_focusOfTheHead runAction:action completionHandler:^{
                _headIsMoving = NO;
            }];
        });
    }
}

- (void)followUserWithEyes:(simd_float3)target{
    
    [self randomlyUpdate:_leftEyeTargetOffset];
    [self randomlyUpdate:_rightEyeTargetOffset];
    _focusOfLeftEye.simdPosition = target + _leftEyeTargetOffset;
    _focusOfRightEye.simdPosition = target + _rightEyeTargetOffset;
}

#pragma mark    -   react

- (void)reactToDidApplyConstraints:(ARSCNView *)sceneView{
    
    SCNNode *pointOfView = sceneView.pointOfView;
    if (!pointOfView || !_modelLoaded) {
        return;
    }
    
    SCNVector3 translationLocal = SCNVector3Make(0, 0, -0.012);
    SCNVector3 translationWorld = [pointOfView convertVector:translationLocal toNode:nil];
    SCNMatrix4 canTransform = SCNMatrix4Translate(pointOfView.transform, translationWorld.x, translationWorld.y, translationWorld.z);
    simd_float3 userPosition = simd_make_float3(canTransform.m41, canTransform.m42, canTransform.m43);
    
    [self updateTongueWithTarget:userPosition];
}

- (void)updateTongueWithTarget:(simd_float3)target{
    
    if (_mouthAnimationState == shootingTongue) {
        if (_relativeTongueStickOutFactor < 1) {
            _relativeTongueStickOutFactor += 0.08;
        }else{
            _relativeTongueStickOutFactor = 1;
        }
    }else if (_mouthAnimationState == pullingBackTongue){
        if (_relativeTongueStickOutFactor > 0) {
            _relativeTongueStickOutFactor -= 0.02;
        }else{
            _relativeTongueStickOutFactor = 0;
        }
    }
    
    simd_float3 startPos = _tongueRestPositionNode.presentationNode.simdWorldPosition;
    simd_float3 intermediatePos = (target - startPos) * _relativeTongueStickOutFactor;
    
    _currentTonguePosition = startPos + intermediatePos;
    _tongueTip.simdPosition = [_tongueTip.parentNode simdConvertVector:_currentTonguePosition toNode:nil];
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

@end
