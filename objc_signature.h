#import <ObjFW/OFObject.h>

#if defined(OF_HAVE_BLOCKS)
const char * of_block_signature(id block);

const char * of_block_to_imp_signature(const char * signature);

const char * of_block_to_cfunction_signature(const char * signature);

#endif

const char * of_imp_to_cfunction_signature(const char * signature);

const char * of_next_type(const char * signature);

const char * of_skip_type_qualifiers(const char * signature);

const char * of_skip_array(const char * signature);

const char * of_skip_struct(const char * signature);

const char * of_skip_union(const char * signature);
