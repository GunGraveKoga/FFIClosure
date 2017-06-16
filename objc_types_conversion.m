#import <ObjFW/ObjFW.h>
#import "objc_types_conversion.h"
#import "objc_signature.h"

static void OF_INLINE skipName(const char ** signature) {
    while (**signature != '=')
        (*signature)++;

    (*signature)++;
}

static size_t OF_INLINE sint_size_of_type(char type) {
    switch (type) {
        case 'B':
            return sizeof(_Bool);
        case 'c':
            return sizeof(signed char);
        case 's':
            return sizeof(short);
        case 'i':
            return sizeof(int);
        case 'l':
            return sizeof(long);
        case 'q':
            return sizeof(long long);
        default:
            break;
    }

    OF_UNREACHABLE;
}

static size_t OF_INLINE uint_size_of_type(char type) {
    switch (type) {
        case 'C':
            return sizeof(unsigned char);
        case 'S':
            return sizeof(unsigned short);
        case 'I':
            return sizeof(unsigned int);
        case 'L':
            return sizeof(unsigned long);
        case 'Q':
            return sizeof(unsigned long long);
        default:
            break;
    }

    OF_UNREACHABLE;
}

static size_t OF_INLINE int_size_of_type(char type) {
    switch (type) {
        case 'B':
        case 'c':
        case 's':
        case 'i':
        case 'l':
        case 'q':
            return sint_size_of_type(type);
        case 'C':
        case 'S':
        case 'I':
        case 'L':
        case 'Q':
            return uint_size_of_type(type);
        default:
            break;
    }

    OF_UNREACHABLE;
} /* int_size_of_type */

static ffi_type * sint_ffi_type(size_t typeSize) {
    switch (typeSize) {
        case 1:
            return &ffi_type_sint8;
        case 2:
            return &ffi_type_sint16;
        case 4:
            return &ffi_type_sint32;
        case 8:
            return &ffi_type_sint64;
        default:
            break;
    }

    OF_UNREACHABLE;
}

static ffi_type * uint_ffi_type(size_t typeSize) {
    switch (typeSize) {
        case 1:
            return &ffi_type_uint8;
        case 2:
            return &ffi_type_uint16;
        case 4:
            return &ffi_type_uint32;
        case 8:
            return &ffi_type_uint64;
        default:
            break;
    }

    OF_UNREACHABLE;
}

static ffi_type * int_type_to_ffi_type(char type) {
    size_t typeSize = int_size_of_type(type);

    switch (type) {
        case 'B':
        case 'c':
        case 's':
        case 'i':
        case 'l':
        case 'q':
            return sint_ffi_type(typeSize);
        case 'C':
        case 'S':
        case 'I':
        case 'L':
        case 'Q':
            return uint_ffi_type(typeSize);
        default:
            break;
    }

    OF_UNREACHABLE;
} /* int_type_to_ffi_type */

static ffi_type * complex_ffi_type(char type) {
    switch (type) {
        case 'f':
            return &ffi_type_complex_float;
        case 'd':
            return &ffi_type_complex_double;
        case 'D':
            return &ffi_type_complex_longdouble;
        default:
            break;
    }

    OF_UNREACHABLE;
}

ffi_type * of_ctype_to_ffi_type(const char * type, void *(*allocator)(void *, size_t), void * ctx) {
    switch (type[0]) {
        case 'B':
        case 'c':
        case 's':
        case 'i':
        case 'l':
        case 'q':
        case 'C':
        case 'S':
        case 'I':
        case 'L':
        case 'Q':
            return int_type_to_ffi_type(type[0]);
        case '@':
        case '#':
        case ':':
        case '*':
        case '^':
        case '[':
            return &ffi_type_pointer;
        case 'f':
            return &ffi_type_float;
        case 'd':
            return &ffi_type_double;
        case 'D':
            return &ffi_type_longdouble;
        case 'j':
            return complex_ffi_type(type[1]);
        case '{':
            return of_cstruct_to_ffi_struct(type, allocator, ctx);
        case 'v':
            return &ffi_type_void;
        default:
            break;
    } /* switch */

    OF_UNREACHABLE;
} /* ctype_to_ffi_type */

static ffi_type * parseArray(const char * signature, size_t * count, void *(*allocator)(void *, size_t), void * ctx) {
    const char * signPtr = signature;
    ffi_type * result = NULL;

    size_t arraySize = 0;

    while (*signPtr >= '0' && *signPtr <= '9')
        arraySize = (arraySize * 10) + (size_t)((*signPtr) - '0');

    *count = (arraySize == 0) ? 1 : arraySize;

    if (*signPtr == '[') {
        arraySize = 0;

        result = parseArray((signPtr + 1), &arraySize, allocator, ctx);

        if ((SIZE_MAX - *count) < arraySize)
            @throw [OFOutOfRangeException exception];

        *count += arraySize;

    } else {
        result = of_ctype_to_ffi_type(signPtr, allocator, ctx);
    }

    return result;
} /* parseArray */

ffi_type * of_cstruct_to_ffi_struct(const char * type, void *(*allocator)(void *, size_t), void * ctx) {

    if (NULL == allocator)
        @throw [OFInvalidArgumentException exception];

    ffi_type * ffiStruct = NULL;

    const char * typePtr = type;
    const char * end = of_skip_struct(type);

    OFDataArray * elementsLocal = [[OFDataArray alloc] initWithItemSize:sizeof(ffi_type *)];

    skipName(&typePtr);

    do {
        ffi_type * element = NULL;

        @try {

            if (*typePtr == '[') {

                size_t arraySize = 0;

                element = parseArray((typePtr + 1), &arraySize, allocator, ctx);

                [elementsLocal addItems:element count:arraySize];

                typePtr = of_skip_array(typePtr);

                continue;
            }

            element = of_ctype_to_ffi_type(typePtr, allocator, ctx);


            if (NULL == element)
                OF_UNREACHABLE;

            [elementsLocal addItem:&element];

        } @catch (id e) {
            [elementsLocal release];

            @throw e;
        }

        typePtr = of_next_type(typePtr);

    } while (typePtr != NULL && (typePtr != (end - 1)) && *typePtr);

    size_t elementsCount = [elementsLocal count] + 1;

    ffi_type ** elements = allocator(ctx, elementsCount * sizeof(ffi_type *));

    if (elements == NULL) {
        [elementsLocal release];
        @throw [OFOutOfMemoryException exceptionWithRequestedSize:(elementsCount * sizeof(ffi_type *))];
    }

    memcpy(elements, [elementsLocal items], ([elementsLocal count] * [elementsLocal itemSize]));

    elements[elementsCount - 1] = NULL;

    ffiStruct = allocator(ctx, sizeof(*ffiStruct));

    if (ffiStruct == NULL) {
        [elementsLocal release];
        @throw [OFOutOfMemoryException exceptionWithRequestedSize:sizeof(*ffiStruct)];
    }

    ffiStruct->type = FFI_TYPE_STRUCT;
    ffiStruct->elements = elements;


    [elementsLocal release];

    return ffiStruct;
} /* cstruct_to_ffi_struct */

int of_cfunction_argc(const char * signature) {
    int argc = -1;

    const char * signPtr = signature;

    while ((signPtr = of_next_type(signPtr)) != NULL)
        argc++;

    return argc;
}

ffi_type ** of_cfunction_args_list(const char * signature, int * argc, ffi_type ** rvalue, void *(*allocator)(void *, size_t), void * ctx) {
    const char * signPtr = signature;

    int _argc = of_cfunction_argc(signPtr);

    ffi_type ** argv = allocator(ctx, ((size_t)_argc * sizeof(*argv)));

    if (NULL == argv)
        @throw [OFOutOfMemoryException exceptionWithRequestedSize:((size_t)_argc * sizeof(*argv))];

    int i = -1;

    do {
        if (i >= 0)
            argv[i] = of_ctype_to_ffi_type(signPtr, allocator, ctx);
        else {
            if (NULL != rvalue)
                *rvalue = of_ctype_to_ffi_type(signPtr, allocator, ctx);
        }

        i++;

    }  while ((signPtr = of_next_type(signPtr)) != NULL);

    *argc = _argc;

    return argv;

} /* of_cfunction_args_list */
