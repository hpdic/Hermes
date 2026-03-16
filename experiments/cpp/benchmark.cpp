/**
 * @file benchmark.cpp
 * @author Dongfang Zhao (dzhao@uw.edu)
 * * @brief Micro-benchmark evaluating homomorphic addition and aggregation 
 * performance across Paillier (IPCL), standard FHE (OpenFHE), and Hermes.
 *
 * @details
 * This program isolates the core cryptographic operations from the database engine 
 * to compare the execution time of various homomorphic algorithms across different 
 * vector slot scales (from 128 to 8192 slots). It initializes both Intel's Paillier 
 * Cryptosystem Library (IPCL) and OpenFHE (BFVRNS scheme) and evaluates four 
 * specific execution paths:
 * * 1. Paillier Add: Element-wise scalar addition simulating standard iteration 
 * without SIMD support. Scales linearly with the number of slots.
 * 2. Hermes SIMD Add: Vectorized addition leveraging packed FHE ciphertexts 
 * to process multiple slots via single instruction multiple data (SIMD).
 * 3. Standard FHE Aggregation: Traditional FHE aggregation requiring O(log N) 
 * computationally expensive Galois rotations and additions.
 * 4. Hermes Rotation-Free Aggregation: O(1) aggregation utilizing Hermes's 
 * pre-computed auxiliary aggregate slot, bypassing rotational overhead.
 * * @dependencies
 * - OpenFHE (v1.0.0+)
 * - Intel Paillier Cryptosystem Library (IPCL)
 * - OpenMP (Required for IPCL acceleration)
 *
 * @section Compilation & Execution
 * @code
 * # 1. Compile the benchmark
 * g++ -std=c++17 benchmark.cpp -o benchmark.out \
 * -I/home/cc/hpdic/pailliercryptolib/ipcl/include \
 * -I/home/cc/hpdic/pailliercryptolib/build/ext_ipp-crypto/ippcrypto_install/opt/intel/ipcl/include \
 * -I/usr/local/include/openfhe \
 * -I/usr/local/include/openfhe/core \
 * -I/usr/local/include/openfhe/pke \
 * -I/usr/local/include/openfhe/binfhe \
 * -L/home/cc/hpdic/pailliercryptolib/build/ipcl \
 * -L/home/cc/hpdic/pailliercryptolib/build/ext_ipp-crypto/ippcrypto_install/opt/intel/ipcl/lib/intel64 \
 * -L/usr/local/lib \
 * -lipcl -lippcp -lcrypto -lOPENFHEpke -lOPENFHEcore -fopenmp
 * * # 2. Export library paths
 * export LD_LIBRARY_PATH=/home/cc/hpdic/pailliercryptolib/build/ipcl:/home/cc/hpdic/pailliercryptolib/build/ext_ipp-crypto/ippcrypto_install/opt/intel/ipcl/lib/intel64:/usr/local/lib:$LD_LIBRARY_PATH
 * * # 3. Execute
 * ./benchmark.out
 * @endcode
 * * @section Example Output
 * @code
 * Initializing FHE and IPCL parameters...
 * Starting multi-scale benchmark...
 * * --- Testing Scale: 128 Slots ---
 * Paillier Add: 1.94735 ms
 * Hermes SIMD Add: 1.72359 ms
 * Standard FHE Aggregation: 630.192 ms
 * Hermes Rotation-Free Aggregation: 1.58602 ms
 * * ... [Intermediate scales omitted for brevity] ...
 * * --- Testing Scale: 8192 Slots ---
 * Paillier Add: 120.567 ms
 * Hermes SIMD Add: 1.56857 ms
 * Standard FHE Aggregation: 1165.94 ms
 * Hermes Rotation-Free Aggregation: 1.57973 ms
 * @endcode
 */

#include <iostream>
#include <chrono>
#include <vector>
#include <ipcl/ipcl.hpp>
#include <openfhe.h>

using namespace lbcrypto;

int main() {
    std::cout << "Initializing FHE and IPCL parameters...\n";

    ipcl::KeyPair ipcl_key = ipcl::generateKeypair(2048);
    std::vector<uint32_t> val1(1, 1);
    std::vector<uint32_t> val2(1, 2);
    ipcl::PlainText pt1(val1);
    ipcl::PlainText pt2(val2);
    ipcl::CipherText ct1_ipcl = ipcl_key.pub_key.encrypt(pt1);
    ipcl::CipherText ct2_ipcl = ipcl_key.pub_key.encrypt(pt2);

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
    for (int i = 1; i < 8192; i *= 2) {
        indexList.push_back(i);
    }
    context->EvalRotateKeyGen(keyPair.secretKey, indexList);

    std::vector<int64_t> vectorOfInts(8192, 1);
    Plaintext plaintext = context->MakePackedPlaintext(vectorOfInts);
    Ciphertext<DCRTPoly> ct_fhe1 = context->Encrypt(keyPair.publicKey, plaintext);
    Ciphertext<DCRTPoly> ct_fhe2 = context->Encrypt(keyPair.publicKey, plaintext);

    std::cout << "Starting multi-scale benchmark...\n\n";

    for (int current_slots = 128; current_slots <= 8192; current_slots *= 2) {
        std::cout << "--- Testing Scale: " << current_slots << " Slots ---\n";

        auto t1 = std::chrono::high_resolution_clock::now();
        for (int i = 0; i < current_slots; ++i) {
            ipcl::CipherText ct3 = ct1_ipcl + ct2_ipcl;
        }
        auto t2 = std::chrono::high_resolution_clock::now();

        auto t3 = std::chrono::high_resolution_clock::now();
        Ciphertext<DCRTPoly> ct_add_res = context->EvalAdd(ct_fhe1, ct_fhe2);
        auto t4 = std::chrono::high_resolution_clock::now();

        auto t5 = std::chrono::high_resolution_clock::now();
        Ciphertext<DCRTPoly> ct_agg_std = ct_fhe1;
        for (int i = 1; i < current_slots; i *= 2) {
            Ciphertext<DCRTPoly> rotated = context->EvalRotate(ct_agg_std, i);
            ct_agg_std = context->EvalAdd(ct_agg_std, rotated);
        }
        auto t6 = std::chrono::high_resolution_clock::now();

        auto t7 = std::chrono::high_resolution_clock::now();
        Ciphertext<DCRTPoly> ct_agg_hermes = context->EvalAdd(ct_fhe1, ct_fhe2);
        auto t8 = std::chrono::high_resolution_clock::now();

        double paillier_time = std::chrono::duration<double, std::milli>(t2 - t1).count();
        double hermes_add_time = std::chrono::duration<double, std::milli>(t4 - t3).count();
        double std_fhe_agg_time = std::chrono::duration<double, std::milli>(t6 - t5).count();
        double hermes_agg_time = std::chrono::duration<double, std::milli>(t8 - t7).count();

        std::cout << "Paillier Add: " << paillier_time << " ms\n";
        std::cout << "Hermes SIMD Add: " << hermes_add_time << " ms\n";
        std::cout << "Standard FHE Aggregation: " << std_fhe_agg_time << " ms\n";
        std::cout << "Hermes Rotation-Free Aggregation: " << hermes_agg_time << " ms\n\n";
    }

    return 0;
}

/**
 * To compile and run this code, use the following commands in the terminal:
g++ -std=c++17 benchmark.cpp -o benchmark.out -I/home/cc/hpdic/pailliercryptolib/ipcl/include -I/home/cc/hpdic/pailliercryptolib/build/ext_ipp-crypto/ippcrypto_install/opt/intel/ipcl/include -I/usr/local/include/openfhe -I/usr/local/include/openfhe/core -I/usr/local/include/openfhe/pke -I/usr/local/include/openfhe/binfhe -L/home/cc/hpdic/pailliercryptolib/build/ipcl -L/home/cc/hpdic/pailliercryptolib/build/ext_ipp-crypto/ippcrypto_install/opt/intel/ipcl/lib/intel64 -L/usr/local/lib -lipcl -lippcp -lcrypto -lOPENFHEpke -lOPENFHEcore -fopenmp
export LD_LIBRARY_PATH=/home/cc/hpdic/pailliercryptolib/build/ipcl:/home/cc/hpdic/pailliercryptolib/build/ext_ipp-crypto/ippcrypto_install/opt/intel/ipcl/lib/intel64:/usr/local/lib:$LD_LIBRARY_PATH
./benchmark.out
 */

 /**
  * Example output:
(venv) cc@a100:~/hpdic/Hermes/experiments/cpp$ ./benchmark.out
Initializing FHE and IPCL parameters...
Starting multi-scale benchmark...

--- Testing Scale: 128 Slots ---
Paillier Add: 1.94735 ms
Hermes SIMD Add: 1.72359 ms
Standard FHE Aggregation: 630.192 ms
Hermes Rotation-Free Aggregation: 1.58602 ms

--- Testing Scale: 256 Slots ---
Paillier Add: 3.79137 ms
Hermes SIMD Add: 1.54893 ms
Standard FHE Aggregation: 725.202 ms
Hermes Rotation-Free Aggregation: 1.78463 ms

--- Testing Scale: 512 Slots ---
Paillier Add: 7.55414 ms
Hermes SIMD Add: 1.64355 ms
Standard FHE Aggregation: 809.227 ms
Hermes Rotation-Free Aggregation: 1.59773 ms

--- Testing Scale: 1024 Slots ---
Paillier Add: 15.2528 ms
Hermes SIMD Add: 1.55728 ms
Standard FHE Aggregation: 899.136 ms
Hermes Rotation-Free Aggregation: 1.57844 ms

--- Testing Scale: 2048 Slots ---
Paillier Add: 30.2376 ms
Hermes SIMD Add: 1.5579 ms
Standard FHE Aggregation: 986.457 ms
Hermes Rotation-Free Aggregation: 1.57942 ms

--- Testing Scale: 4096 Slots ---
Paillier Add: 60.1356 ms
Hermes SIMD Add: 1.57927 ms
Standard FHE Aggregation: 1078.02 ms
Hermes Rotation-Free Aggregation: 1.57126 ms

--- Testing Scale: 8192 Slots ---
Paillier Add: 120.567 ms
Hermes SIMD Add: 1.56857 ms
Standard FHE Aggregation: 1165.94 ms
Hermes Rotation-Free Aggregation: 1.57973 ms

(venv) cc@a100:~/hpdic/Hermes/experiments/cpp$ 
  */