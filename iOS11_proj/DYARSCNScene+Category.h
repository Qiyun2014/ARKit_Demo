//
//  ARSCNView+ARSCNView_Category.h
//  iOS11_proj
//
//  Created by IYNMac on 26/9/17.
//  Copyright © 2017年 IYNMac. All rights reserved.
//

#import <ARKit/ARKit.h>

@interface ARSCNView (ARSCNView_Category)

- (SCNVector3)averageColorFromEnvironment:(SCNVector3)screenPos;

@end


@interface SCNAnimation (SCNAnimation_Category)

// Get current rootnode animation
- (SCNAnimation *)fromFileWithName:(NSString *)name inDirectory:(NSString *)directory;

@end


@interface UIImage (UIImage_Category)

// Get r、g、b、a value from image
- (SCNVector3)averageColor;

@end
