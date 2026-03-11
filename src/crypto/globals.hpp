/*
 * File: src/crypto/globals.hpp
 * -------------------------------------------------------------------
 * Declares global constants for the HERMES crypto module, including
 * default file paths for storing and retrieving BFV public and secret
 * keys. These constants are primarily intended for debugging and
 * prototyping purposes, allowing stateless function calls to reuse
 * a predefined key directory.
 *
 * WARNING: Hardcoded paths are insecure and should not be used in
 * production deployments without appropriate access control.
 *
 * Author: Dongfang Zhao (dzhao@uw.edu)
 * Institution: University of Washington
 * Last Updated: March 10, 2026
 */

#pragma once

#include <string>

namespace hermes::crypto {

// Default directory for key storage (for debug/demo use only)
inline const std::string kKeyDir = "/tmp/Hermes";
inline const std::string kPubKeyPath = kKeyDir + "/hermes_pub.key";
inline const std::string kSecKeyPath = kKeyDir + "/hermes_sec.key";
inline const std::string kGaloisKeyPath = kKeyDir + "/hermes_galois.key";
inline const std::string kRelinKeyPath = kKeyDir + "/hermes_relin.key";

} // namespace hermes::crypto