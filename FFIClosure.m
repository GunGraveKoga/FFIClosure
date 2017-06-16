#import <ObjFW/ObjFW.h>
#import "FFIClosure.h"
#import "objc_types_conversion.h"

@interface FFIClosure ()
@end

@implementation FFIClosure

@synthesize closureHandle = _closureHandle;

#if defined(OF_HAVE_BLOCKS)
+ (instancetype) closureWithBlock:(id)block {
    return [[[self alloc] initWithBlock:block] autorelease];
}

+ (instancetype) closureAsImpImplementationWithBlock:(id)block {
    return [[[self alloc] initAsImpImplementationWithBlock:block] autorelease];
}

+ (instancetype) closureWithTarget:(id)target selector:(SEL)selector {
    return [[[self alloc] initWithTarget:target selector:selector] autorelease];
}

- (instancetype) initWithBlock:(id)block {
    self = [super init];

    if ((_closureHandle = ffi_closure_new(FFI_TRAMPOLINE_BLOCK, block)) == FFI_INVALID_HANDLE) {
        OFInitializationFailedException * exception = [OFInitializationFailedException exceptionWithClass:[self class]];

        [self release];

        @throw exception;
    }

    return self;
} /* initWithBlock */

- (instancetype) initAsImpImplementationWithBlock:(id)block {
    self = [super init];

    if ((_closureHandle = ffi_closure_new(FFI_TRAMPOLINE_BLOCK_IMP, block)) == FFI_INVALID_HANDLE) {
        OFInitializationFailedException * exception = [OFInitializationFailedException exceptionWithClass:[self class]];

        [self release];

        @throw exception;
    }

    return self;
} /* initAsImpImplementationWithBlock */
#endif /* if defined(OF_HAVE_BLOCKS) */

- (instancetype) initWithTarget:(id)target selector:(SEL)selector {
    self = [super init];

    if ((_closureHandle = ffi_closure_new(FFI_TRAMPOLINE_SEL_IMP, target, selector)) == FFI_INVALID_HANDLE) {
        OFInitializationFailedException * exception = [OFInitializationFailedException exceptionWithClass:[self class]];

        [self release];

        @throw exception;
    }

    return self;
} /* initWithTarget */

- (void *) function {
    return ffi_closure_function(self.closureHandle);
}


- (void) dealloc {

    if (_closureHandle != FFI_INVALID_HANDLE)
        ffi_closure_delete(_closureHandle);

    [super dealloc];
}

@end
