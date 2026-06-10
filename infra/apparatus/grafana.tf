data "aws_iam_policy_document" "grafana_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.grafana_cloud_account_id}:root"]
    }

    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [var.grafana_cloud_external_id]
    }
  }
}

resource "aws_iam_role" "grafana_cloud_cw" {
  name               = "DdaGrafanaCloudCloudWatch"
  description        = "Read-only CloudWatch access for the DDA Grafana Cloud data source"
  assume_role_policy = data.aws_iam_policy_document.grafana_trust.json
}

resource "aws_iam_role_policy_attachment" "grafana_cloudwatch_ro" {
  role       = aws_iam_role.grafana_cloud_cw.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"
}
