#import <ObjFW/ObjFW.h>
#import "objc_associate.h"
#import "FFIClosure.h"

/*
 *
 * Borrowed from  Apple libobjc4 sources
 *
 */

enum {
    OBJC_ASSOCIATION_SETTER_ASSIGN      = 0,
    OBJC_ASSOCIATION_SETTER_RETAIN      = 1,
    OBJC_ASSOCIATION_SETTER_COPY        = 3,            // NOTE:  both bits are set, so we can simply test 1 bit in releaseValue below.
    OBJC_ASSOCIATION_GETTER_READ        = (0 << 8),
    OBJC_ASSOCIATION_GETTER_RETAIN      = (1 << 8),
    OBJC_ASSOCIATION_GETTER_AUTORELEASE = (2 << 8)
};

static OF_INLINE uintptr_t DISGUISE(id value) {
    return ~(uintptr_t)(value);
}
static OF_INLINE id UNDISGUISE(uintptr_t uptr) {
    return (id)(~uptr);
}

static OFMutex * _objc_associate_lock = nil;

static of_once_t once = OF_ONCE_INIT;

static OFMutableDictionary OF_GENERIC(OFNumber *, OFMutableDictionary *) * _objc_associate_objects_map = nil;

static void _objc_associate_init(void) {
    _objc_associate_lock = [OFMutex new];

    _objc_associate_objects_map = [OFMutableDictionary new];
}

static id acquireValue(id value, uintptr_t policy) {
    switch (policy & 0xFF) {
        case OBJC_ASSOCIATION_SETTER_RETAIN:
            return [value retain];
        case OBJC_ASSOCIATION_SETTER_COPY:
            return [value copy];
    }
    return value;
}

static void releaseValue(uintptr_t value, uintptr_t policy) {
    if (policy & OBJC_ASSOCIATION_SETTER_RETAIN) {
        id val = UNDISGUISE(value);
        [val release];
    }
}

@interface ObjcAssociation : OFObject
{
    uintptr_t _policy;
    uintptr_t _value;
}
@property(nonatomic, readonly) uintptr_t policy;
@property(nonatomic, readonly) uintptr_t value;
- (instancetype) initWithPolicy:(uintptr_t)policy value:(id)value;
@end


id of_objc_getAssociatedObject(id object, void * key) {
    of_once(&once, &_objc_associate_init);

    id value = nil;
    uintptr_t policy = OBJC_ASSOCIATION_ASSIGN;

    [_objc_associate_lock lock];

    OFException * exc = nil;

    void * pool = objc_autoreleasePoolPush();

    @try {
        OFNumber * valueKey = [OFNumber numberWithUIntPtr:DISGUISE(key)];
        OFNumber * objectKey = [OFNumber numberWithUIntPtr:DISGUISE(object)];
        OFMutableDictionary OF_GENERIC(OFNumber *, ObjcAssociation *) * refs = [_objc_associate_objects_map objectForKey:objectKey];

        if (refs != nil) {
            ObjcAssociation * entry = [refs objectForKey:valueKey];

            if (entry != nil) {
                value = UNDISGUISE(entry.value);
                policy = entry.policy;

                if (policy & OBJC_ASSOCIATION_GETTER_RETAIN)
                    value = [value retain];
            }
        }

    } @catch (id e) {
        exc = [e retain];

        @throw;

    } @finally {
        objc_autoreleasePoolPop(pool);

        if (exc != nil)
            [exc autorelease];

        [_objc_associate_lock unlock];
    }

    if (value && (policy & OBJC_ASSOCIATION_GETTER_AUTORELEASE))
        return [value autorelease];

    return value;
} /* of_objc_getAssociatedObject */

void of_objc_setAssociatedObject(id object, void * key, id value, objc_AssociationPolicy policy) {
    of_once(&once, &_objc_associate_init);

    [_objc_associate_lock lock];

    void * pool = objc_autoreleasePoolPush();

    OFException * exc = nil;

    @try {
        ObjcAssociation * new_association = [[[ObjcAssociation alloc] initWithPolicy:policy value:value] autorelease];
        OFNumber * objectKey = [OFNumber numberWithUIntPtr:DISGUISE(object)];
        OFNumber * valueKey = [OFNumber numberWithUIntPtr:DISGUISE(key)];

        OFMutableDictionary OF_GENERIC(OFNumber *, ObjcAssociation *) * refs = [_objc_associate_objects_map objectForKey:objectKey];

        if (UNDISGUISE(new_association.value) != nil) {

            if (refs != nil) {

                [refs setObject:new_association forKey:valueKey];

            } else {
                OFMutableDictionary OF_GENERIC(OFNumber *, ObjcAssociation *) * new_refs = [OFMutableDictionary dictionary];

                [new_refs setObject:new_association forKey:valueKey];

                [_objc_associate_objects_map setObject:new_refs forKey:objectKey];

            }

        } else {

            if (refs != nil) {
                [refs removeObjectForKey:valueKey];
            }
        }
    } @catch (id e) {
        exc = [e retain];

        @throw;

    } @finally {
        objc_autoreleasePoolPop(pool);

        if (exc != nil)
            [exc autorelease];

        [_objc_associate_lock unlock];
    }

} /* of_objc_setAssociatedObject */

void of_objc_removeAssociatedObjects(id object) {
    of_once(&once, &_objc_associate_init);

    [_objc_associate_lock lock];

    OFException * exc = nil;

    void * pool = objc_autoreleasePoolPush();

    @try {

        OFNumber * objectKey = [OFNumber numberWithUIntPtr:DISGUISE(object)];

        [_objc_associate_objects_map removeObjectForKey:objectKey];

    } @catch (id e) {
        exc = [e retain];

        @throw;

    }@finally {
        objc_autoreleasePoolPop(pool);

        if (exc != nil)
            [exc autorelease];

        [_objc_associate_lock unlock];
    }
} /* of_objc_removeAssociatedObjects */


id objc_getAssociatedObject(id object, void * key) {
    return of_objc_getAssociatedObject(object, key);
}

void objc_setAssociatedObject(id object, void * key, id value, objc_AssociationPolicy policy) {
    if ((policy & OBJC_ASSOCIATION_COPY_NONATOMIC) == OBJC_ASSOCIATION_COPY_NONATOMIC)
        value = [value copy];

    of_objc_setAssociatedObject(object, key, value, policy);
}

void objc_removeAssociatedObjects(id object) {
    of_objc_removeAssociatedObjects(object);
}


@implementation ObjcAssociation
@synthesize policy = _policy;
@synthesize value = value;

- (instancetype) initWithPolicy:(uintptr_t)aPolicy value:(id)aValue {
    self = [super init];

    _value = DISGUISE(acquireValue(aValue, aPolicy));

    _policy = aPolicy;

    return self;
}

- (void) dealloc {
    releaseValue(_value, _policy);

    [super dealloc];
}
@end

#if defined(OF_HAVE_BLOCKS)

IMP imp_implementationWithBlock(id block) {
    of_once(&once, &_objc_associate_init);

    IMP imp = NULL;

    [_objc_associate_lock lock];

    OFNumber * objectKey = [[OFNumber alloc] initWithUIntPtr:DISGUISE(block)];

    @try {

        OFMutableDictionary OF_GENERIC(OFNumber *, ObjcAssociation *) * associates = [_objc_associate_objects_map objectForKey:objectKey];

        if (associates != nil) {
            for (ObjcAssociation * entry in [associates allObjects]) {
                id val = UNDISGUISE(entry.value);
                if ([val isKindOfClass:[FFIClosure class]]) {
                    imp = (IMP)([(FFIClosure *)(val)function]);

                    return imp;
                }
            }
        }

    } @finally {
        [objectKey release];

        [_objc_associate_lock lock];
    }

    FFIClosure * new_closure = [[FFIClosure alloc] initAsImpImplementationWithBlock:block];

    void * key = [new_closure function];

    @try {
        objc_setAssociatedObject(block, key, new_closure, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        imp = (IMP)key;

    } @finally {
        [new_closure release];
    }

    return imp;

} /* imp_implementationWithBlock */

id imp_getBlock(IMP imp) {
    of_once(&once, &_objc_associate_init);

    id block = nil;

    [_objc_associate_lock lock];

    OFException * exc = nil;

    void * pool = objc_autoreleasePoolPush();

    @try {

        OFNumber * valueKey = [OFNumber numberWithUIntPtr:DISGUISE((void *)imp)];

        for (OFNumber * objectKey in _objc_associate_objects_map) {
            OFMutableDictionary OF_GENERIC(OFNumber *, ObjcAssociation *) * refs = [_objc_associate_objects_map objectForKey:objectKey];

            ObjcAssociation * entry = [refs objectForKey:valueKey];

            if (entry != nil) {
                block = UNDISGUISE([objectKey uIntPtrValue]);

                break;
            }
        }

    } @catch (id e) {
        exc = [e retain];

        @throw;

    } @finally {
        objc_autoreleasePoolPop(pool);

        if (exc != nil)
            [exc autorelease];

        [_objc_associate_lock unlock];
    }

    return block;
} /* imp_getBlock */

static void _remove_associate_imp(id block, IMP imp) {
    [_objc_associate_lock lock];

    OFException * exc = nil;

    void * pool = objc_autoreleasePoolPush();

    @try {
        OFNumber * objectKey = [OFNumber numberWithUIntPtr:DISGUISE(block)];
        OFNumber * valueKey = [OFNumber numberWithUIntPtr:DISGUISE((void *)(imp))];

        OFMutableDictionary OF_GENERIC(OFNumber *, ObjcAssociation *) * refs = [_objc_associate_objects_map objectForKey:objectKey];

        [refs removeObjectForKey:valueKey];

        if ([refs count] <= 0)
            [_objc_associate_objects_map removeObjectForKey:objectKey];

    } @catch (id e) {
        exc = [e retain];

        @throw;

    } @finally {
        objc_autoreleasePoolPop(pool);

        if (exc != nil)
            [exc autorelease];

        [_objc_associate_lock unlock];
    }

} /* _remove_associate_imp */

BOOL imp_removeBlock(IMP imp) {
    id block = imp_getBlock(imp);

    if (block == nil) {
        return NO;
    }

    BOOL res;

    @try {
        _remove_associate_imp(block, imp);
        res = YES;
    } @catch (id e) {
        (void)e;
        res = NO;
    }

    return res;
}

#endif /* if defined(OF_HAVE_BLOCKS) */
