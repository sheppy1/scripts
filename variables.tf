variable "backup" {
  type = object({
    type                 = string
    tier                 = optional(string)
    interval_in_minutes  = optional(number)
    retention_in_hours   = optional(number)
    storage_redundancy   = optional(string)
  })

  validation {
    condition = var.backup.type == "Continuous" || var.backup.type == "Periodic"
    error_message = "Invalid value for backup.type. Possible values are Continuous and Periodic."
  }

  validation {
    condition = (
      var.backup.type == "Continuous" || (
        var.backup.tier == null && var.backup.interval_in_minutes == null && var.backup.retention_in_hours == null && var.backup.storage_redundancy == null
      )
    )
    error_message = "Fields tier, interval_in_minutes, retention_in_hours, and storage_redundancy are only configurable when the type field is set to Periodic."
  }

  validation {
    condition = (
      var.backup.tier == null || var.backup.tier == "Continuous7Days" || var.backup.tier == "Continuous30Days"
    )
    error_message = "Invalid value for backup.tier. Possible values are Continuous7Days and Continuous30Days."
  }

  validation {
    condition = (
      var.backup.interval_in_minutes == null || (var.backup.interval_in_minutes >= 60 && var.backup.interval_in_minutes <= 1440)
    )
    error_message = "Invalid value for backup.interval_in_minutes. Must be between 60 and 1440."
  }

  validation {
    condition = (
      var.backup.retention_in_hours == null || (var.backup.retention_in_hours >= 8 && var.backup.retention_in_hours <= 720)
    )
    error_message = "Invalid value for backup.retention_in_hours. Must be between 8 and 720."
  }

  validation {
    condition = (
      var.backup.storage_redundancy == null || var.backup.storage_redundancy == "Geo" || var.backup.storage_redundancy == "Local" || var.backup.storage_redundancy == "Zone"
    )
    error_message = "Invalid value for backup.storage_redundancy. Possible values are Geo, Local, and Zone."
  }
}
