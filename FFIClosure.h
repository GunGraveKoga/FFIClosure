#import <ObjFW/OFObject.h>
#import "objc_ffi_trampoline.h"
#import "objc_signature.h"
#import "objc_associate.h"
#import "objc_types_conversion.h"

OF_ASSUME_NONNULL_BEGIN

@interface FFIClosure : OFObject
{
    ffi_handle_t _closureHandle;
}

@property (nonatomic, readonly) ffi_handle_t closureHandle;

- (instancetype)init OF_UNAVAILABLE;

#if defined(OF_HAVE_BLOCKS)
+ (instancetype)closureWithBlock:(id)block;

- (instancetype)initWithBlock:(id)block OF_DESIGNATED_INITIALIZER;

+ (instancetype)closureAsImpImplementationWithBlock:(id)block;

- (instancetype)initAsImpImplementationWithBlock:(id)block OF_DESIGNATED_INITIALIZER;
#endif
+ (instancetype)closureWithTarget:(id)target selector:(SEL)selector;

- (instancetype)initWithTarget:(id)target selector:(SEL)selector OF_DESIGNATED_INITIALIZER;

- (void *)function;

@end

OF_ASSUME_NONNULL_END
