//
//  DYARView.h
//  iOS11_proj
//
//  Created by IYNMac on 29/9/17.
//  Copyright © 2017年 IYNMac. All rights reserved.
//

#if __has_include(<ARKit/ARKit.h>)
#import <ARKit/ARKit.h>
#endif

#define kARNodeName_sport @"Fight Idle"
#define kARNodeName_dance @"Standing Aim Idle 02 Looking"
static NSString * _Nullable ARNodeFormat = @".dae";

NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, DYARRecordType) {
    DYARRecordTypeDefault = 0,
    DYARRecordTypeStart,
    DYARRecordTypePause,
    DYARRecordTypeResume,
    DYARRecordTypeStop
};

typedef NS_ENUM(NSInteger, DYARModelType) {
    DYARModelTypeUnknow,
    DYARModelTypeSports,
    DYARModelTypeDance
};

typedef NS_ENUM(NSInteger, DYARNodeDetectionMask) {
    DYARNodeDetectionMaskCharacter = 1 << 0,
    DYARNodeDetectionMaskBall = 1 << 1,
    DYARNodeDetectionMaskCategoryBottom = 1 << 2,
    DYARNodeDetectionMaskCategoryCube = 1 << 3,
};

typedef NS_ENUM(NSInteger, DYARParticleType) {
    DYARParticleTypeUnknow = 0,
    DYARParticleTypeRain,
    DYARParticleTypeSnow,
    DYARParticleTypeBomb,
};

@protocol DYARReordDelegate <NSObject>

- (void)willOuputVideoPixelBuffer:(CVPixelBufferRef)pixelBuffer;

@end

#if __has_include(<ARKit/ARKit.h>)
API_AVAILABLE(ios(11.0)) API_UNAVAILABLE(macos, watchos, tvos)
@interface DYARView : ARSCNView
#else
@interface DYARView : UIView
#endif

@property (nonatomic, assign, setter=setParticleType:) DYARParticleType particleType;
@property (nonatomic, assign, setter=setModelType:) DYARModelType modelType;
@property (nonatomic, readonly) SCNNode *rootNode;
@property (nonatomic, strong) SCNAction* startAction;
@property (nonatomic, weak, nullable) id <DYARReordDelegate> recordDelegate;

- (void)updateSceneWithName:(NSString *)name withAnimation:(SCNAction *)action;

@end


@interface DYARView(DYARViewCapture)

- (void)setRecordType:(DYARRecordType)recordType;

@end

@interface SCNNode (DYARAdditions)

// Add the node named 'name' found in the DAE document located at 'path' as a child of the receiver
- (SCNNode *)asc_addChildNodeNamed:(nullable NSString *)name fromSceneNamed:(NSString *)path withScale:(CGFloat)scale;

@end


@interface DYARManNode: SCNNode

@property (nonatomic, strong) SCNAnimation *animation;

- (id)initWithNamed:(NSString *)named;
- (SCNAnimation *)loadAnimationWithSceneName:(NSString *)sceneName;

@end


@interface DYARBallNode: SCNNode

- (id)initWithNode;

@end


@interface DYARPlane: SCNNode

- (id)initWithPlaneAnchor:(ARPlaneAnchor *)anchor isHidden:(BOOL)hidden;
- (void)updatePlaneAnchor:(ARPlaneAnchor *)anchor;
- (void)setTextureScale;
- (void)hide;

@property (nonatomic,retain) ARPlaneAnchor *planeAnchor;
@property (nonatomic, retain) SCNBox *planeGeometry;

@end

NS_ASSUME_NONNULL_END


