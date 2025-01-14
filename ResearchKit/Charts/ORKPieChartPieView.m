/*
 Copyright (c) 2015, Apple Inc. All rights reserved.
 Copyright (c) 2015, James Cox.
 Copyright (c) 2015, Ricardo Sánchez-Sáez.
 
 Redistribution and use in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 
 1.  Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 2.  Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation and/or
 other materials provided with the distribution.
 
 3.  Neither the name of the copyright holder(s) nor the names of any contributors
 may be used to endorse or promote products derived from this software without
 specific prior written permission. No license is granted to the trademarks of
 the copyright holders even if such marks are included in this software.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "ORKPieChartPieView.h"
#import "ORKPieChartView_Internal.h"
#import "ORKHelpers.h"


static const CGFloat OriginAngle = -M_PI_2;
static const CGFloat PercentageLabelOffset = 10.0;
static const CGFloat InterAnimationDelay = 0.05;

@implementation ORKPieChartPieView {
    __weak ORKPieChartView *_parentPieChartView;
    
    CAShapeLayer *_circleLayer;
    NSMutableArray *_normalizedValues;
    NSMutableArray *_segmentLayers;
    NSMutableArray *_pieSections;
}

- (instancetype)initWithFrame:(CGRect)frame {
    ORKThrowMethodUnavailableException();
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [self initWithParentPieChartView:nil];
    return self;
}

- (instancetype)initWithParentPieChartView:(ORKPieChartView *)parentPieChartView {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _parentPieChartView = parentPieChartView;
        self.translatesAutoresizingMaskIntoConstraints = NO;
        
        _circleLayer = [CAShapeLayer layer];
        _circleLayer.fillColor = [UIColor clearColor].CGColor;
        _circleLayer.strokeColor = [UIColor colorWithWhite:0.96 alpha:1.000].CGColor;
        [self.layer addSublayer:_circleLayer];
        
        _normalizedValues = [NSMutableArray new];
        _segmentLayers = [NSMutableArray new];
        _pieSections = [NSMutableArray new];
    }
    return self;
}

- (void)setPercentageLabelFont:(UIFont *)percentageLabelFont {
    _percentageLabelFont = percentageLabelFont;
    for (ORKPieChartSection *pieSection in _pieSections) {
        pieSection.label.font = percentageLabelFont;
        [pieSection.label sizeToFit];
    }
    [self setNeedsLayout];
}

#pragma mark - Data Normalization

- (CGFloat)normalizeValues {
    [_normalizedValues removeAllObjects];
    
    CGFloat sumOfValues = 0;
    NSInteger numberOfSegments = [_parentPieChartView.dataSource numberOfSegmentsInPieChartView:_parentPieChartView];
    for (NSInteger idx = 0; idx < numberOfSegments; idx++) {
        CGFloat value = [_parentPieChartView.dataSource pieChartView:_parentPieChartView valueForSegmentAtIndex:idx];
        sumOfValues += value;
    }
    
    for (NSInteger idx = 0; idx < numberOfSegments; idx++) {
        CGFloat value = 0;
        if (sumOfValues != 0) {
            value = [_parentPieChartView.dataSource pieChartView:_parentPieChartView valueForSegmentAtIndex:idx] / sumOfValues;
        }
        [_normalizedValues addObject:@(value)];
    }
    return sumOfValues;
}

#pragma mark - Layout and drawing

- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect bounds = self.bounds;
    CGFloat startAngle = OriginAngle;
    CGFloat endAngle = startAngle + (2 * M_PI);
    CGFloat outerRadius = bounds.size.height * 0.5;
    CGFloat labelHeight = [@"100%" boundingRectWithSize:CGRectInfinite.size
                                                options:(NSStringDrawingOptions)0
                                             attributes:@{NSFontAttributeName : _percentageLabelFont}
                                                context:nil].size.height;
    CGFloat innerRadius = outerRadius - (labelHeight + PercentageLabelOffset);
    CGFloat targetRadius = _parentPieChartView.showsPercentageLabels ? innerRadius : outerRadius;
    CGFloat lineWidth = MIN(_parentPieChartView.lineWidth, targetRadius);
    _circleLayer.lineWidth = lineWidth;
    CGFloat drawingRadius = targetRadius - (lineWidth * 0.5);
    
    if (!_parentPieChartView.drawsClockwise) {
        startAngle = 3 * M_PI_2;
        endAngle = -M_PI_2;
    }
    UIBezierPath *circularArcBezierPath = [UIBezierPath bezierPathWithArcCenter:CGPointMake(CGRectGetMidX(bounds),
                                                                                            CGRectGetMidY(bounds))
                                                                         radius:drawingRadius
                                                                     startAngle:startAngle
                                                                       endAngle:endAngle
                                                                      clockwise:_parentPieChartView.drawsClockwise];
    
    _circleLayer.path = circularArcBezierPath.CGPath;
    
    [self layoutPieChartLayers];
    if (_parentPieChartView.showsPercentageLabels) {
        [self layoutPercentageLabelsWithRadius:innerRadius];
    }
}

- (void)updatePieLayers {
    [_segmentLayers makeObjectsPerformSelector:@selector(removeFromSuperlayer)];
    [_segmentLayers removeAllObjects];
    
    CGFloat cumulativeValue = 0;
    NSInteger numberOfSegments = [_parentPieChartView.dataSource numberOfSegmentsInPieChartView:_parentPieChartView];
    for (NSInteger idx = 0; idx < numberOfSegments; idx++) {
        
        CAShapeLayer *segmentLayer = [CAShapeLayer layer];
        segmentLayer.fillColor = [[UIColor clearColor] CGColor];
        segmentLayer.frame = _circleLayer.bounds;
        segmentLayer.path = _circleLayer.path;
        segmentLayer.lineWidth = _circleLayer.lineWidth;
        segmentLayer.strokeColor = [_parentPieChartView colorForSegmentAtIndex:idx].CGColor;
        CGFloat value = ((NSNumber *)_normalizedValues[idx]).floatValue;
        
        if (value != 0) {
            if (idx == 0) {
                segmentLayer.strokeStart = 0.0;
            } else {
                segmentLayer.strokeStart = cumulativeValue;
            }
            
            segmentLayer.strokeEnd = cumulativeValue;
            [_circleLayer addSublayer:segmentLayer];
            [_segmentLayers addObject:segmentLayer];
            segmentLayer.strokeEnd = cumulativeValue + value;
        }
        cumulativeValue += value;
    }
}

- (void)updatePercentageLabels {
    for (ORKPieChartSection *pieSection in _pieSections) {
        [pieSection.label removeFromSuperview];
    }
    [_pieSections removeAllObjects];
    
    if (_parentPieChartView.showsPercentageLabels) {
        CGFloat cumulativeValue = 0;
        NSInteger numberOfSegments = [_parentPieChartView.dataSource numberOfSegmentsInPieChartView:_parentPieChartView];
        for (NSInteger idx = 0; idx < numberOfSegments; idx++) {
            CGFloat value = ((NSNumber *)_normalizedValues[idx]).floatValue;
            
            if (value != 0) {
                
                // Create a label
                UILabel *label = [UILabel new];
                label.text = [NSString stringWithFormat:@"%0.0f%%", (value < .01) ? 1 :value * 100];
                label.font = _percentageLabelFont;
                label.textColor = [_parentPieChartView colorForSegmentAtIndex:idx];
                [label sizeToFit];
                
                // Calculate the angle to the centre of this segment in radians
                CGFloat angle = 0;
                if (_parentPieChartView.drawsClockwise) {
                    angle = (value / 2 + cumulativeValue) * M_PI * 2;
                } else {
                    angle = (value / 2 + cumulativeValue) * - M_PI * 2;
                }
                
                cumulativeValue += value;
                ORKPieChartSection *pieSection = [[ORKPieChartSection alloc] initWithLabel:label angle:angle];
                [_pieSections addObject:pieSection];
                [self addSubview:label];
            }
        }
    }
}

- (void)layoutPieChartLayers {
    NSInteger numberOfSegments = [_parentPieChartView.dataSource numberOfSegmentsInPieChartView:_parentPieChartView];
    for (NSInteger idx = 0; idx < numberOfSegments; idx++) {
        CAShapeLayer *segmentLayer = _segmentLayers[idx];
        segmentLayer.frame = _circleLayer.bounds;
        segmentLayer.path = _circleLayer.path;
        segmentLayer.lineWidth = _circleLayer.lineWidth;
    }
}

- (void)layoutPercentageLabelsWithRadius:(CGFloat)pieRadius {
    CGFloat cumulativeValue = 0;
    NSInteger numberOfSegments = [_parentPieChartView.dataSource numberOfSegmentsInPieChartView:_parentPieChartView];
    for (NSInteger idx = 0; idx < numberOfSegments; idx++) {
        CGFloat value = ((NSNumber *)_normalizedValues[idx]).floatValue;
        if (value != 0) {
            // Create a label
            ORKPieChartSection *pieSection = _pieSections[idx];
            UILabel *label = pieSection.label;
            
            // Calculate the angle to the centre of this segment in radians
            CGFloat angle = (value / 2 + cumulativeValue) * M_PI * 2;
            if (!_parentPieChartView.drawsClockwise) {
                angle = (value / 2 + cumulativeValue) * - M_PI * 2;
            }
            
            label.center = [self percentageLabel:label calculateCenterForAngle:angle pieRadius:pieRadius];
            cumulativeValue += value;
        }
    }
    [self adjustIntersectionsOfPercentageLabels:_pieSections pieRadius:pieRadius];
}

- (CGPoint)percentageLabel:(UILabel *)label calculateCenterForAngle:(CGFloat)angle pieRadius:(CGFloat)pieRadius {
    // Calculate the desired distance from the circle's centre.
    const CGFloat offset = 10;
    CGFloat length = pieRadius + offset;
    
    // Calculate x and y coordinates for the point at this distance at the specified angle.
    CGSize size = self.bounds.size;
    CGFloat cosine = cos(angle + OriginAngle);
    CGFloat sine = sin(angle + OriginAngle);
    CGFloat x = cosine * length + size.width / 2;
    CGFloat y = sine *  length + size.height / 2;
    
    // Offset (x,y) to normalise the spacing from the circle's centre to the intersection with the label's frame rather than its centre.
    CGSize labelSize = [label systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
    CGFloat xIn = cosine * labelSize.width / 2;
    CGFloat yIn = sine * labelSize.height / 2;
    x += xIn;
    y += yIn;
    
    return  CGPointMake(x, y);
}

- (void)adjustIntersectionsOfPercentageLabels:(NSArray *)pieSections pieRadius:(CGFloat)pieRadius {
    if (pieSections.count == 0) {
        return;
    }
    // Adjust labels while we have intersections
    BOOL intersections = YES;
    // We alternate directions in each iteration
    BOOL shiftClockwise = NO;
    CGFloat rotateDirection = _parentPieChartView.drawsClockwise ? 1 : -1;
    // We use totalAngle to prevent from infinite loop
    CGFloat totalAngle = 0;
    while (intersections) {
        intersections = NO;
        shiftClockwise = !shiftClockwise;
        
        if (shiftClockwise) {
            for (NSUInteger idx = 0; idx < (pieSections.count - 1); idx++) {
                // Prevent from infinite loop
                if (!idx) {
                    totalAngle += 0.01;
                    if (totalAngle >= 2 * M_PI) {
                        return;
                    }
                }
                ORKPieChartSection *pieLabel  = pieSections[idx];
                ORKPieChartSection *nextPieLabel = pieSections[(idx + 1)];
                if ([self shiftSectionLabel:nextPieLabel fromSectionLabel:pieLabel direction:rotateDirection pieRadius:pieRadius]) {
                    intersections = YES;
                }
            }
        } else {
            for (NSInteger idx = pieSections.count - 1; idx > 0; idx--) {
                ORKPieChartSection *pieLabel = pieSections[idx];
                ORKPieChartSection *nextPieLabel = pieSections[idx - 1];
                if ([self shiftSectionLabel:nextPieLabel fromSectionLabel:pieLabel direction:-rotateDirection pieRadius:pieRadius]) {
                    intersections = YES;
                }
            }
        }
        
        // Adjust space between last and first element
        ORKPieChartSection *firstPieLabel = pieSections.firstObject;
        ORKPieChartSection *lastPieLabel = pieSections.lastObject;
        UILabel *firstLabel = firstPieLabel.label;
        UILabel *lastLabel = lastPieLabel.label;
        if (CGRectIntersectsRect(lastLabel.frame, firstLabel.frame)) {
            CGFloat firstLabelAngle = firstPieLabel.angle;
            CGFloat lastLabelAngle = lastPieLabel.angle;
            firstLabelAngle += rotateDirection * 0.01;
            lastLabelAngle -= rotateDirection * 0.01;
            firstPieLabel.angle = firstLabelAngle;
            lastPieLabel.angle = lastLabelAngle;
        }
    }
}

- (BOOL)shiftSectionLabel:(ORKPieChartSection *)nextPieSection
         fromSectionLabel:(ORKPieChartSection *)fromPieSection
                direction:(CGFloat)direction
                pieRadius:(CGFloat)pieRadius {
    CGFloat shiftStep = 0.01;
    UILabel *label = fromPieSection.label;
    UILabel *nextLabel = nextPieSection.label;
    if (CGRectIntersectsRect(label.frame, nextLabel.frame)) {
        CGFloat nextLabelAngle = nextPieSection.angle;
        nextLabelAngle += direction * shiftStep;
        nextPieSection.angle = nextLabelAngle;
        nextLabel.center = [self percentageLabel:nextLabel calculateCenterForAngle:nextLabelAngle pieRadius:pieRadius];
        return YES;
    }
    return NO;
}

- (void)animateWithDuration:(NSTimeInterval)animationDuration {
    NSUInteger pieSectionCount = _pieSections.count;
    NSTimeInterval interAnimationDelay = InterAnimationDelay;
    NSTimeInterval singleAnimationDuration = animationDuration - (interAnimationDelay * (pieSectionCount-1));
    if (singleAnimationDuration < 0) {
        interAnimationDelay = 0;
        singleAnimationDuration = animationDuration;
    }
    
    CGFloat cumulativeValue = 0;
    for (NSInteger idx = 0; idx < pieSectionCount; idx++) {
        ORKPieChartSection *section = _pieSections[idx];
        UILabel *label = section.label;
        label.alpha = 0;
        [UIView animateWithDuration:singleAnimationDuration
                              delay:interAnimationDelay * idx
                            options:(UIViewAnimationOptions)0
                         animations:^{
                             label.alpha = 1.0;
                         }
                         completion:nil];
        
        CAShapeLayer *segmentLayer = _segmentLayers[idx];
        CGFloat value = ((NSNumber *)_normalizedValues[idx]).floatValue;
        CABasicAnimation *strokeAnimation = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
        strokeAnimation.fromValue = @(segmentLayer.strokeStart);
        strokeAnimation.toValue = @(cumulativeValue + value);
        strokeAnimation.duration = animationDuration;
        strokeAnimation.removedOnCompletion = NO;
        strokeAnimation.fillMode = kCAFillModeForwards;
        strokeAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [segmentLayer addAnimation:strokeAnimation forKey:@"strokeAnimation"];
        
        cumulativeValue += value;
    }
}

@end
