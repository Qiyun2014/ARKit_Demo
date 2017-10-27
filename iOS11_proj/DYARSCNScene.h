//
//  DYARSCNScene.h
//  iOS11_proj
//
//  Created by IYNMac on 25/9/17.
//  Copyright © 2017年 IYNMac. All rights reserved.
//

#import <SceneKit/SceneKit.h>
#import <ARKit/ARKit.h>

@interface DYARSCNScene : SCNScene

- (void)reactToTap:(ARSCNView *)sceneView;
- (void)reactToPositionChange:(ARSCNView *)view;
- (void)reactToRendering:(ARSCNView *)sceneView;
- (void)reactToDidApplyConstraints:(ARSCNView *)sceneView;

- (void)show;
- (void)hide;
- (BOOL)isVisible;
- (void)setTransform:(simd_float4x4)transform;

@end
