#include <iostream>
#include <chrono>
#include <vector>
#include <ipcl/ipcl.hpp>
#include <openfhe.h>

using namespace lbcrypto;

int main() {
    int slots = 8192;
    std::cout << "Initializing keys...\n";

    // IPCL Setup
    ipcl::KeyPair ipcl_key = ipcl::generateKeypair(2048);
    std::vector<uint32_t> val1(1, 1);
    std::vector<uint32_t> val2(1, 2);
    ipcl::PlainText pt1(val1);
    ipcl::PlainText pt2(val2);
    ipcl::CipherText ct1_ipcl = ipcl_key.pub_key.encrypt(pt1);
    ipcl::CipherText ct2_ipcl = ipcl_key.pub_key.encrypt(pt2);

    // OpenFHE Setup
    CCParams<CryptoContextBFVRNS> parameters;
    parameters.SetPlaintextModulus(65537);
    parameters.SetMultiplicativeDepth(2);

    CryptoContext<DCRTPoly> context = GenCryptoContext(parameters);
    context->Enable(PKE);
    context->Enable(KEYSWITCH);
    context->Enable(LEVELEDSHE);
    context->Enable(ADVANCEDSHE);

    KeyPair<DCRTPoly> keyPair = context->KeyGen();
    context->EvalMultKeyGen(keyPair.secretKey);

    std::vector<int32_t> indexList;
    for (int i = 1; i < slots; i *= 2) {
        indexList.push_back(i);
    }
    context->EvalRotateKeyGen(keyPair.secretKey, indexList);

    std::vector<int64_t> vectorOfInts(slots, 1);
    Plaintext plaintext = context->MakePackedPlaintext(vectorOfInts);
    Ciphertext<DCRTPoly> ct_fhe1 = context->Encrypt(keyPair.publicKey, plaintext);
    Ciphertext<DCRTPoly> ct_fhe2 = context->Encrypt(keyPair.publicKey, plaintext);

    // 1. Paillier Addition Loop
    auto t1 = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < slots; ++i) {
        ipcl::CipherText ct3 = ct1_ipcl + ct2_ipcl;
    }
    auto t2 = std::chrono::high_resolution_clock::now();

    // 2. Hermes FHE SIMD Addition
    auto t3 = std::chrono::high_resolution_clock::now();
    Ciphertext<DCRTPoly> ct_add_res = context->EvalAdd(ct_fhe1, ct_fhe2);
    auto t4 = std::chrono::high_resolution_clock::now();

    // 3. Standard FHE Aggregation (log N rotations and additions)
    auto t5 = std::chrono::high_resolution_clock::now();
    Ciphertext<DCRTPoly> ct_agg_std = ct_fhe1;
    for (int i = 1; i < slots; i *= 2) {
        Ciphertext<DCRTPoly> rotated = context->EvalRotate(ct_agg_std, i);
        ct_agg_std = context->EvalAdd(ct_agg_std, rotated);
    }
    auto t6 = std::chrono::high_resolution_clock::now();

    // 4. Hermes Rotation-Free Aggregation
    auto t7 = std::chrono::high_resolution_clock::now();
    Ciphertext<DCRTPoly> ct_agg_hermes = context->EvalAdd(ct_fhe1, ct_fhe2);
    auto t8 = std::chrono::high_resolution_clock::now();

    double paillier_time = std::chrono::duration<double, std::milli>(t2 - t1).count();
    double hermes_add_time = std::chrono::duration<double, std::milli>(t4 - t3).count();
    double std_fhe_agg_time = std::chrono::duration<double, std::milli>(t6 - t5).count();
    double hermes_agg_time = std::chrono::duration<double, std::milli>(t8 - t7).count();

    std::cout << "Paillier Add (" << slots << " slots): " << paillier_time << " ms\n";
    std::cout << "Hermes SIMD Add: " << hermes_add_time << " ms\n";
    std::cout << "Standard FHE Aggregation: " << std_fhe_agg_time << " ms\n";
    std::cout << "Hermes Rotation-Free Aggregation: " << hermes_agg_time << " ms\n";

    return 0;
}

/**
 * To compile and run this code, use the following commands in the terminal:
g++ -std=c++17 benchmark.cpp -o benchmark.out -I/home/cc/hpdic/pailliercryptolib/ipcl/include -I/home/cc/hpdic/pailliercryptolib/build/ext_ipp-crypto/ippcrypto_install/opt/intel/ipcl/include -I/usr/local/include/openfhe -I/usr/local/include/openfhe/core -I/usr/local/include/openfhe/pke -I/usr/local/include/openfhe/binfhe -L/home/cc/hpdic/pailliercryptolib/build/ipcl -L/home/cc/hpdic/pailliercryptolib/build/ext_ipp-crypto/ippcrypto_install/opt/intel/ipcl/lib/intel64 -L/usr/local/lib -lipcl -lippcp -lcrypto -lOPENFHEpke -lOPENFHEcore -fopenmp
export LD_LIBRARY_PATH=/home/cc/hpdic/pailliercryptolib/build/ipcl:/home/cc/hpdic/pailliercryptolib/build/ext_ipp-crypto/ippcrypto_install/opt/intel/ipcl/lib/intel64:/usr/local/lib:$LD_LIBRARY_PATH
./benchmark.out
 */