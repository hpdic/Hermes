#include <iostream>
#include <vector>
#include <ipcl/ipcl.hpp>

int main() {
    ipcl::KeyPair key = ipcl::generateKeypair(1024);
    
    std::vector<uint32_t> raw_data = {2026};
    ipcl::PlainText pt(raw_data);
    
    ipcl::CipherText ct = key.pub_key.encrypt(pt);
    ipcl::PlainText dec_pt = key.priv_key.decrypt(ct);
    
    std::vector<uint32_t> dec_data = dec_pt;
    
    if (dec_data[0] == 2026) {
        std::cout << "IPCL installation successful!" << std::endl;
    } else {
        std::cout << "Decryption failed." << std::endl;
    }
    
    return 0;
}

/**
g++ hello_ipcl.cpp -o hello_ipcl.out -lipcl -lcrypto
./hello_ipcl.out
 */