/**
 * @file hello_ipcl.cpp
 * @author Dongfang Zhao (dzhao@uw.edu)
 * * @brief A basic validation and initialization test for the Intel Paillier Cryptosystem Library.
 *
 * @details
 * This program serves as a fundamental sanity check to verify the proper installation 
 * and configuration of the IPCL environment. It executes a complete cryptographic 
 * lifecycle by generating a 1024 bit Paillier keypair, encrypting a scalar integer 
 * value, decrypting the corresponding ciphertext, and validating the integrity of 
 * the recovered plaintext against the original input. Successful execution confirms 
 * that the library headers and compiled binaries are correctly linked.
 * * @dependencies
 * Intel Paillier Cryptosystem Library
 * * @section Compilation and Execution
 * @code
 * g++ -std=c++17 hello_ipcl.cpp -o hello_ipcl.out -I/home/cc/hpdic/pailliercryptolib/ipcl/include -I/home/cc/hpdic/pailliercryptolib/build/ext_ipp-crypto/ippcrypto_install/opt/intel/ipcl/include -L/home/cc/hpdic/pailliercryptolib/build/ipcl -L/home/cc/hpdic/pailliercryptolib/build/ext_ipp-crypto/ippcrypto_install/opt/intel/ipcl/lib/intel64 -lipcl -lippcp -lcrypto
 * export LD_LIBRARY_PATH=/home/cc/hpdic/pailliercryptolib/build/ipcl:/home/cc/hpdic/pailliercryptolib/build/ext_ipp-crypto/ippcrypto_install/opt/intel/ipcl/lib/intel64:$LD_LIBRARY_PATH
 * ./hello_ipcl.out
 * @endcode
 * * @section Example Output
 * @code
 * IPCL installation successful!
 * @endcode
 */

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

/** To compile and run this code, use the following commands in the terminal:
g++ -std=c++17 hello_ipcl.cpp -o hello_ipcl.out -I/home/cc/hpdic/pailliercryptolib/ipcl/include -I/home/cc/hpdic/pailliercryptolib/build/ext_ipp-crypto/ippcrypto_install/opt/intel/ipcl/include -L/home/cc/hpdic/pailliercryptolib/build/ipcl -L/home/cc/hpdic/pailliercryptolib/build/ext_ipp-crypto/ippcrypto_install/opt/intel/ipcl/lib/intel64 -lipcl -lippcp -lcrypto
export LD_LIBRARY_PATH=/home/cc/hpdic/pailliercryptolib/build/ipcl:/home/cc/hpdic/pailliercryptolib/build/ext_ipp-crypto/ippcrypto_install/opt/intel/ipcl/lib/intel64:$LD_LIBRARY_PATH
./hello_ipcl.out
 */