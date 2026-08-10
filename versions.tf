terraform {
  required_version = ">= 1.3"

  required_providers {
    tencentcloud = {
      source = "tencentcloudstack/tencentcloud"
      # 控制中心（Control Center）账号工厂基线资源自 v1.82.44 起提供
      version = ">= 1.82.50"
    }
  }
}
