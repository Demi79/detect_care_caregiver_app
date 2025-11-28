class L10nVi {
  static const title = 'Hóa đơn';
  static const noInvoices = 'Không có hóa đơn nào.';
  static const retry = 'Thử lại';
  static const pullToLoadMore = 'Kéo để tải thêm...';

  static String invoiceTitle(String id) => 'Hóa đơn #$id';
  static String invoiceDisplayTitle(String id) => 'Hóa đơn';
  static const issuedDate = 'Ngày tạo';
  static const paidDate = 'Ngày thanh toán';
  static const total = 'Tổng tiền';
  static const details = 'Chi tiết';
  static const tax = 'Thuế';
  static const qty = 'Số lượng';
  static const unitPrice = 'Đơn giá';
  static const lineTotal = 'Thành tiền';
  static const description = 'Mô tả';

  // Snooze / alert related
  static const snooze30s = 'Tạm dừng 30 giây';
  static const snooze1m = 'Tạm dừng 1 phút';
  static const snooze5m = 'Tạm dừng 5 phút';

  static const statusPaid = 'Đã thanh toán';
  static const statusFailed = 'Thất bại';
  static const plan = 'Gói dịch vụ';
  static const copiedInvoiceId = 'Đã sao chép mã hóa đơn';
  static const downloadPdf = 'Tải PDF';
  static const share = 'Chia sẻ';
  static const close = 'Đóng';
  // Pagination
  static const previous = 'Trước';
  static const next = 'Tiếp';
  static const page = 'Trang';
  // Filters / pagination UI
  static const filterSortTitle = 'Bộ lọc & sắp xếp';
  static const status = 'Trạng thái';
  static const source = 'Nguồn';
  static const sort = 'Sắp xếp';
  static const itemsPerPage = 'Mục/trang';
  static const jumpToPage = 'Nhảy tới trang';
  static const go = 'Đi';
  static const all = 'Tất cả';
  static const vnpay = 'VNPay';
  static const manual = 'Manual';
  static const newest = 'Mới nhất';
  static const oldest = 'Cũ nhất';
  static const amountDesc = 'Giá trị ↓';
  static const amountAsc = 'Giá trị ↑';

  static String totalInvoices(int n) => 'Tổng: $n hóa đơn';
}
