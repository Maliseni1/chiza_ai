// File: lib/core/model_constants.dart
class ModelConstants {
  // The exact file name we will use everywhere
  static const String fileName = "deepseek-r1-distill-qwen-1.5b-q4_k_m.gguf";

  // The URL to download from (Using a reliable HuggingFace direct link)
  static const String downloadUrl =
      "https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q8_0.gguf";
  // Note: I kept the URL pointing to Qwen 0.5B as it is small and fast for testing,
  // but we are saving it with a standard name so you can swap it later easily.
}
