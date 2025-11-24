class QRCodeGenerator {
  static String generate(String participationId) {
    final uuid = participationId.toLowerCase();
    final countA = uuid.split('a').length - 1;
    return 'FEV-$uuid$countA';
  }
}
