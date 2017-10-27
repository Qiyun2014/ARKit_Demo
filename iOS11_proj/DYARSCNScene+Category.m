//
//  ARSCNView+ARSCNView_Category.m
//  iOS11_proj
//
//  Created by IYNMac on 26/9/17.
//  Copyright © 2017年 IYNMac. All rights reserved.
//

#import "DYARSCNScene+Category.h"
#import <CoreImage/CoreImage.h>

@implementation ARSCNView (ARSCNView_Category)

- (SCNVector3)averageColorFromEnvironment:(SCNVector3)screenPos{
    
    SCNVector3 colorVector;
    
    self.scene.rootNode.hidden = YES;
    UIImage *screenShot = [self snapshot];
    self.scene.rootNode.hidden = NO;
    float scale = [[UIScreen mainScreen] scale];
    float patchSize = 100 *scale;
    
    CGPoint screenPoint = CGPointMake((screenPos.x - patchSize / 2) * scale, (screenPos.y - patchSize / 2) * scale);
    CGRect cropRect = CGRectMake(screenPoint.x, screenPoint.y, patchSize, patchSize);
    CGImageRef imageRef = CGImageCreateWithImageInRect([screenShot CGImage], cropRect);
    UIImage *newImage = [UIImage imageWithCGImage:imageRef];
    
    SCNVector3 vector = [newImage averageColor];
    colorVector = SCNVector3Make(vector.x, vector.y, vector.z);
    return colorVector;
}

@end


@implementation SCNAnimation (SCNAnimation_Category)

- (SCNAnimation *)fromFileWithName:(NSString *)name inDirectory:(NSString *)directory{
    
    SCNScene *animScene = [SCNScene sceneNamed:name inDirectory:directory options:nil];
    __block SCNAnimation *animation;
    [animScene.rootNode enumerateChildNodesUsingBlock:^(SCNNode * _Nonnull child, BOOL * _Nonnull stop) {
       
        if (child.animationKeys.count > 0) {
            SCNAnimationPlayer *player = [child animationPlayerForKey:child.animationKeys[0]];
            animation = player.animation;
            *stop = YES;
        }
    }];
    return animation;
}

@end


@implementation UIImage (UIImage_Category)

- (SCNVector3)averageColor{
    
    CGImageRef cgImage = self.CGImage;
    CIFilter *averageFilter = [CIFilter filterWithName:@"CIAreaAverage"];
    if (cgImage && averageFilter) {
        
        CIImage *ciImage = [CIImage imageWithCGImage:cgImage];
        CGRect extent = ciImage.extent;
        CIVector *ciExtent = [CIVector vectorWithX:extent.origin.x Y:extent.origin.y Z:extent.size.width W:extent.size.height];
        [averageFilter setValue:ciImage forKey:kCIInputImageKey];
        [averageFilter setValue:ciExtent forKey:kCIInputExtentKey];
        
        CIImage *outputImage = averageFilter.outputImage;
        if (outputImage) {
            CIContext *context = [CIContext contextWithOptions:nil];
            UInt8 bitmap[4];
            [context render:outputImage toBitmap:&bitmap rowBytes:4 bounds:CGRectMake(0, 0, 1, 1) format:kCIFormatRGBA8 colorSpace:CGColorSpaceCreateDeviceRGB()];
            SCNVector3 newVector = SCNVector3Make(((float)bitmap[0])/255.0, ((float)bitmap[1])/255.0, ((float)bitmap[2])/255.0);
            return newVector;
        }
    }
    return SCNVector3Zero;
}

@end
