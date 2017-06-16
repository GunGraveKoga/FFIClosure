#import <ObjFW/ObjFW.h>
#import "objc_signature.h"
#include <assert.h>

static void OF_INLINE skipNumbers(const char ** signature) {
    while (**signature >= '0' && **signature <= '9')
        (*signature)++;
}

static void OF_INLINE skipName(const char ** signature) {
    while (**signature != '=')
        (*signature)++;

    (*signature)++;
}

#if defined (OF_HAVE_BLOCKS)

enum {
    OFBlockDescriptionFlagsHasCopyDispose = (1 << 25),
    OFBlockDescriptionFlagsHasCtor = (1 << 26), // helpers have C++ code
    OFBlockDescriptionFlagsIsGlobal = (1 << 28),
    OFBlockDescriptionFlagsHasStret = (1 << 29), // IFF BLOCK_HAS_SIGNATURE
    OFBlockDescriptionFlagsHasSignature = (1 << 30)
};
typedef int OFBlockDescriptionFlags;

const char * of_block_signature(id block) {
    of_block_literal_t * blockLiteral = (__bridge void *)block;

    OFBlockDescriptionFlags flags = blockLiteral->flags;

    // unsigned long size = blockLiteral->descriptor->size;

    if (flags & OFBlockDescriptionFlagsHasSignature) {
        void * signatureLocation = (void *)blockLiteral->descriptor;

        signatureLocation += (sizeof(unsigned long) * 2);

        if (flags & OFBlockDescriptionFlagsHasCopyDispose) {
            signatureLocation += sizeof(void (*)(void * dst, void * src));
            signatureLocation += sizeof(void (*)(void * src));
        }

        const char * signature = (*(const char **)signatureLocation);

        return signature;

    }

    return NULL;
} /* blockSignature */

#endif /* if defined (OF_HAVE_BLOCKS) */


static void OF_INLINE skipReturnValue(char ** signature) {
    *signature += (of_next_type(*signature) - *signature);
}

const char * of_block_to_imp_signature(const char * signature) {
    char * imp_signature = strdup(signature);

    if (NULL == imp_signature)
        return NULL;

    char * replace = imp_signature;

    skipReturnValue(&replace);

    if (*replace != '@' && *(replace + 1) != '?') {
        free(imp_signature);

        return NULL;
    }
    replace++;

    memmove(replace, replace + 1, strlen(replace));

    skipNumbers(&replace);

    if (*replace != '@') {
        free(imp_signature);
        return NULL;
    }

    *replace = ':';

    return (const char *)imp_signature;
} /* of_block_to_imp_signature */

const char * of_block_to_cfunction_signature(const char * signature) {
    char * fnc_signature = strdup(signature);

    if (NULL == fnc_signature)
        return NULL;

    char * replace = fnc_signature;

    skipReturnValue(&replace);

    if (*replace != '@' && *(replace + 1) != '?') {
        free(fnc_signature);

        return NULL;
    }

    char * n = replace;

    n += 2;

    skipNumbers(&n);

    memmove(replace, n, strlen(n) + 1);

    return (const char *)fnc_signature;
} /* of_block_to_cfunction_signature */

const char * of_imp_to_cfunction_signature(const char * signature) {
    char * fnc_signature = strdup(signature);

    if (NULL == fnc_signature)
        return NULL;

    char * replace = fnc_signature;

    skipReturnValue(&replace);

    if (*replace != '@') {
        free(fnc_signature);

        return NULL;
    }

    char * n = replace;

    n++;

    skipNumbers(&n);

    if (*n != ':') {
        free(fnc_signature);
        return NULL;
    }

    n++;

    skipNumbers(&n);

    memmove(replace, n, strlen(n) + 1);

    return (const char *)fnc_signature;
} /* of_imp_to_cfunction_signature */

const char * of_skip_type_qualifiers(const char * signature) {
    const char * signPtr = signature;

    do {

        switch (*signPtr) {
            case 'r':
            case 'n':
            case 'N':
            case 'o':
            case 'O':
            case 'R':
            case 'V':
                signPtr++;
                break;
            default:
                return signPtr;
        }

    } while (signPtr && *signPtr);

    OF_UNREACHABLE;
} /* of_skip_type_qualifiers */

const char * of_skip_array(const char * signature) {
    const char * signPtr = signature + 1;

    skipNumbers(&signPtr);

    while (signPtr && *signPtr) {
        signPtr = of_next_type(signPtr);

        if (*signPtr == ']') {
            signPtr++;
            break;
        }
    }

    return signPtr;

}

const char * of_skip_struct(const char * signature) {
    const char * signPtr = signature + 1;

    skipName(&signPtr);

    while (signPtr && *signPtr) {
        signPtr = of_next_type(signPtr);

        if (*signPtr == '}') {
            signPtr++;
            break;
        }
    }

    return signPtr;
}

const char * of_skip_union(const char * signature) {
    const char * signPtr = signature + 1;

    skipName(&signPtr);

    while (signPtr && *signPtr) {
        signPtr = of_next_type(signPtr);

        if (*signPtr == ')') {
            signPtr++;
            break;
        }
    }

    return signPtr;
}

const char * of_next_type(const char * signature) {
    if (NULL == signature || *signature == '\0')
        return NULL;

    const char * signPtr = of_skip_type_qualifiers(signature);

    switch (*signPtr) {
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
        case 'f':
        case 'd':
        case 'D':
        case '#':
        case ':':
        case '*':
        case 'v':
        case '?':
            signPtr++;
            break;
        case '^':
            return of_next_type(++signPtr);
        case '@':
        {
            signPtr++;
            if (*signPtr == '?')
                signPtr++;
        }
        break;
        case '[':
            signPtr = of_skip_array(signPtr);
            break;
        case '{':
            signPtr = of_skip_struct(signPtr);
            break;
        case '(':
            signPtr = of_skip_union(signPtr);
            break;
        default:
            OF_UNREACHABLE;


    } /* switch */

    skipNumbers(&signPtr);

    return signPtr;
} /* of_next_type */
