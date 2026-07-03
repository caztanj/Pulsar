main :: () {
    input := "Hello World!";
    hash: [LibreSSL.SHA256_DIGEST_LENGTH] u8;
    sha256: LibreSSL.SHA256_CTX;

    LibreSSL.SHA256_Init(*sha256);
    LibreSSL.SHA256_Update(*sha256, input.data, xx input.count);
    LibreSSL.SHA256_Final(hash.data, *sha256);

    print("SHA256(\"%\") = ", input);

    for hash {
        print("%", formatInt(it, base = 16));
    }

    print("\n");
}

#import "Basic";
LibreSSL :: #import,dir "..";