#FFIClosure

###Description
**FFIClosure** is a Objective-C wrapper for libffi for [ObjFW](https://github.com/Midar/objfw)
**FFIClosure** use libffi trampolines implementation to extend ObjFW functionality and flexibility and add to ObjFW some Apple Objective-C/Objective-C 2.0 features.

###Features
**FFIClosure** supports automatic mapping of block / method types to libffi types, based on the signatures that Clang creates at compile time, even for С-struct types.

###Limitations
**FFIClosure** does not support unions as closure arguments or return-type

###Requirements
- ObjFW v0.9-dev or higher
- libffi v3.2.1 or higher
- Optional: Clang 3.8 or higher (for Blocks-Runtime)

###FFIClosure wrapper class features
####Create ffi_closure from Block-closure with any Block-signature to create function pointer with signature < Block-return-type >(*)(Block-arguments-types list)
```objc
+ (instancetype)closureWithBlock:(id)block;

- (instancetype)initWithBlock:(id)block;
```
####Create ffi_closure from Block with signature < Any >(^)(__unsafe_unretained id, ...) to create IMP function pointer with signature < Any >(*)(id, SEL, ...)
```objc
+ (instancetype)closureAsImpImplementationWithBlock:(id)block;

- (instancetype)initAsImpImplementationWithBlock:(id)block;
```
####Create ffi_closure from ObjC Object method to create function pointer with sinature < Method-return-type >(*)(Method-arguments-types list) with excluded id and SEL arguments
```objc
+ (instancetype)closureWithTarget:(id)target selector:(SEL)selector;

- (instancetype)initWithTarget:(id)target selector:(SEL)selector;
```
####Get void* pointer castable to pointer to function
```objc
- (void *)function;
```

###Apple Objective-C/Objective-C 2.0 features
####Create method implementation from block in Apple ObjC style
```objc
IMP imp_implementationWithBlock(id block);
```
####Get Block from IMP
```objc
id imp_getBlock(IMP imp);
```
####Remove Block associated with IMP
```objc
BOOL imp_removeBlock(IMP imp);
```
####Association ObjC-Object with another ObjC-Object (Dynamic properties and ivars for example)
```objc
id objc_getAssociatedObject(id object, void * key);

void objc_setAssociatedObject(id object, void * key, id value, objc_AssociationPolicy policy);

void objc_removeAssociatedObjects(id object);
```

###Utils
####Some useful functions for working with Blocks/Methods signatures
```objc
const char * of_block_signature(id block);

const char * of_block_to_imp_signature(const char * signature);

const char * of_block_to_cfunction_signature(const char * signature);

const char * of_imp_to_cfunction_signature(const char * signature);
```
###Usage example
```objc
int (*callback_function)(int, float, const char *);

__block OFMutableString *message = [OFMutableString string];

FFIClosure *closure = [FFIClosure closureWithBlock:^int(int a, float b, const char *str) {
	[message appendFormat:@"Message from C callback! %d, %f, %s", a, b, str];
    
    return 0;
}];

callback_function = (__typeof__(callback_function))[closure function];

call_C_public_API_function_with_callback(callback_function);

of_log(@"Result message:%@", message);

```