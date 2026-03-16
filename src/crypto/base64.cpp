/**
 * @file base64.cpp
 * @author Dongfang Zhao (dzhao@uw.edu)
 *
 * @brief High-performance Base64 encoding and decoding utilities for Hermes.
 *
 * @details
 * This module provides the necessary serialization logic to convert binary 
 * homomorphic ciphertexts into ASCII strings. This conversion is essential for 
 * storing cryptographic payloads within standard SQL text columns (e.g., LONGTEXT) 
 * and ensuring safe transmission over text-based database protocols. The 
 * implementation uses bitwise shifting for efficient conversion between 8-bit 
 * binary data and 6-bit Base64 indices, including standard padding support.
 *
 * @namespace hermes::crypto
 * Provides a localized scope for cryptographic utility functions used 
 * throughout the Hermes system.
 *
 * @dependencies
 * - standard string and vector libraries
 * - base64.hpp (header definition)
 */

#include "base64.hpp"

namespace hermes::crypto {

static const std::string b64_chars =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

std::string encodeBase64(const std::string &in) {
  std::string out;
  int val = 0, valb = -6;
  for (uint8_t c : in) {
    val = (val << 8) + c;
    valb += 8;
    while (valb >= 0) {
      out.push_back(b64_chars[(val >> valb) & 0x3F]);
      valb -= 6;
    }
  }
  if (valb > -6)
    out.push_back(b64_chars[((val << 8) >> (valb + 8)) & 0x3F]);
  while (out.size() % 4)
    out.push_back('=');
  return out;
}

std::string decodeBase64(const std::string &in) {
  std::vector<int> T(256, -1);
  for (int i = 0; i < 64; i++)
    T[b64_chars[i]] = i;
  std::string out;
  int val = 0, valb = -8;
  for (uint8_t c : in) {
    if (T[c] == -1)
      break;
    val = (val << 6) + T[c];
    valb += 6;
    if (valb >= 0) {
      out.push_back(char((val >> valb) & 0xFF));
      valb -= 8;
    }
  }
  return out;
}

} // namespace hermes::crypto