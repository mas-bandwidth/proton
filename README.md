<img width="2204" height="1232" alt="image" src="https://github.com/user-attachments/assets/8b904825-212f-480c-a84c-dc7831ac8c6a" />

# proton

Proton is a linux kernel module based on [libhydrogen](https://github.com/jedisct1/libhydrogen) that provides crypto functions callable from XDP programs.

# Why?

I created it because I needed to write XDP programs on Linux that do cryptography compatible with userspace programs running on arbitrary platforms.

I considered using Linux cryptographic functions directly, but then I had the problem of working out, OK, but where do I get implementations for these functions across all client platforms that I support? I did not want to burden the user of my client-side libraries with installing huge dependencies like libcurl or mbedtls, just to get access to basic cryptographic functions.

So, when I found libhydrogen it was perfect. With small modifications I was able to wrap it up into a Linux kernel module callable from XDP programs, and then on other platforms clients could just use libhydrogen directly from userspace, and this is no burden on the user at all because libhydrogen is like two c files and has zero dependencies and will compile pretty much anywhere.

Problem solved.

# Usage

Run `./install.sh` to build and install the kernel module and set it to load on boot. You'll need to be running on Ubuntu 24.04 LTS or newer.

Now you can include proton.h in your XDP programs and call crypto functions like this:

```
#define PROTON_SIGN_PUBLIC_KEY_BYTES              32
#define PROTON_SIGN_PRIVATE_KEY_BYTES             64

#define PROTON_SECRETBOX_KEY_BYTES                32
#define PROTON_SECRETBOX_CRYPTO_HEADER_BYTES      36

struct proton_sign_create_args
{
    __u8 private_key[PROTON_SIGN_PRIVATE_KEY_BYTES];
};

struct proton_sign_verify_args
{
    __u8 public_key[PROTON_SIGN_PUBLIC_KEY_BYTES];
};

extern int proton_sha256( void * data, int data__sz, void * output, int output__sz );

extern int proton_sign_create( void * data, int data__sz, void * signature, int signature__sz, struct proton_sign_create_args * args );

extern int proton_sign_verify( void * data, int data__sz, void * signature, int signature__sz, struct proton_sign_verify_args * args );

extern int proton_secretbox_encrypt( void * data, int data__sz, __u64 message_id, void * key, int key__sz );

extern int proton_secretbox_decrypt( void * data, int data__sz, __u64 message_id, void * key, int key__sz );
```

These functions are compatible with crypto done in userspace using the regular libhydrogen, but please note that in some cases I had to simplify or adjust the function signatures to fit the Linux kfunc rules (5 arguments max per-function *and* you must pass in array lengths via __sz for the BPF verifier).
