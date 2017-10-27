//
//  ViewController.m
//  iOS11_proj
//
//  Created by IYNMac on 27/7/17.
//  Copyright © 2017年 IYNMac. All rights reserved.
//

// not supported on this plantform
// /Applications/Xcode.app/Contents/Developer/usr/bin/scntool --convert InFile.dae --format c3d --output OutFile.dae --force-y-up --force-interleaved --look-for-pvrtc-image

#import "ViewController.h"
#import "DYARView.h"

@interface ViewController () <DYARReordDelegate>

@property (nonatomic, strong) DYARView *sceneView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib
    
    self.sceneView = [[DYARView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:self.sceneView];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        //self.sceneView.recordDelegate = self;
        [self.sceneView setRecordType:DYARRecordTypeStart];
    });
    
    UIButton *clothes = [UIButton buttonWithType:UIButtonTypeSystem];
    clothes.frame = CGRectMake(20, 60, 100, 30);
    [clothes setTintColor:[UIColor redColor]];
    [clothes setTitle:@"更换" forState:UIControlStateNormal];
    [self.sceneView addSubview:clothes];
    
    [clothes addTarget:self action:@selector(clothesChangeOfAction:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.sceneView setModelType:DYARModelTypeSports];
}

- (void)clothesChangeOfAction:(UIButton *)button{
    
    [self.sceneView setModelType:DYARModelTypeDance];
    
    return;
    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"articuno-pokemon-go-dae/freezer-1-0" ofType:@".tga"];
    UIImage *image = [UIImage imageWithContentsOfFile:path];
    NSLog(@"image = %@",image);
    self.sceneView.rootNode.geometry.firstMaterial.diffuse.contents = image;
    
    [self.sceneView.rootNode.childNodes enumerateObjectsUsingBlock:^(SCNNode * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        obj.geometry.firstMaterial.diffuse.contents = image;
        NSLog(@"geometry name = %@, all materials = %@",obj.geometry.name, obj.geometry.materials);
    }];
}

- (void)willOuputVideoPixelBuffer:(CVPixelBufferRef)pixelBuffer{
    
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
