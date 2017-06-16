#import <ObjFW/OFObject.h>

enum {
    OBJC_ASSOCIATION_ASSIGN = 0,
    OBJC_ASSOCIATION_RETAIN_NONATOMIC = 1,
    OBJC_ASSOCIATION_COPY_NONATOMIC = 3,
    OBJC_ASSOCIATION_RETAIN = 0x301,
    OBJC_ASSOCIATION_COPY = 0x303
};

typedef uintptr_t objc_AssociationPolicy;

id objc_getAssociatedObject(id object, void * key);

void objc_setAssociatedObject(id object, void * key, id value, objc_AssociationPolicy policy);

void objc_removeAssociatedObjects(id object);

#if defined(OF_HAVE_BLOCKS)

IMP imp_implementationWithBlock(id block);

id imp_getBlock(IMP imp);

BOOL imp_removeBlock(IMP imp);

#endif
