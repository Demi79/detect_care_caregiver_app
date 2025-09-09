class SharedPermissionsEndpoints {
  const SharedPermissionsEndpoints();

  String pair(String customerId, String caregiverId) =>
      '/customers/$customerId/shared-permissions/$caregiverId';
}

SharedPermissionsEndpoints makeSharedPermissionsEndpoints() =>
    const SharedPermissionsEndpoints();
