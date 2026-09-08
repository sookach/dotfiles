return {
  capabilities = {
    textDocument = {
      diagnostic = {
        dynamicRegistration = true,
        relatedDocumentSupport = true
      }
    },
    workspace = {
      didChangeWatchedFiles = {
        dynamicRegistration = true
      }
    }
  },
  cmd = { 'sourcekit-lsp' },
  filetypes = { 'swift' },
  root_markers = {
    '.git',
    'Package.swift',
    'compile_commands.json',
    '*.xcodeproj',
    '*.xcworkspace',
  },
}
