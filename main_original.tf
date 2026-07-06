
# data "archive_file" "lambda_layer" {
#     type = "zip"
#     source_dir = "${path.module}/lambda_layer"
#     output_path = "vmx3_common_python.zip"
# }

# resource "aws_lambda_layer_version" "lambda_layer" {
# #   source = "./lambda_layer"
# #   source_path       = "${path.module}/lambda_layer" # Directory containing your layer content

# #   s3_bucket = "cruz-connectvmx-source-us-gov-west-1"
# #   s3_key    = "vmx3/2025.09.13/zip/vmx3_common_python.zip"

#   filename = data.archive_file.lambda_layer.output_path
  
#   layer_name        = "my_lambda_layer"
#   compatible_runtimes = ["python3.13"]
#   description = "A sample Lambda layer"
# }