package main

// JSONConfigurationSAML to keep all SAML details for auth
type JSONConfigurationSAML struct {
	CertPath    string `json:"certpath"`
	KeyPath     string `json:"keypath"`
	MetaDataURL string `json:"metadataurl"`
	RootURL     string `json:"rooturl"`
}

// JSONAdminUsers to keep all admin users for auth JSON
type JSONAdminUsers struct {
	Username string `json:"username"`
	Password string `json:"password"`
	Fullname string `json:"fullname"`
	Admin    bool   `json:"admin"`
}

// OsqueryTable to show tables to query
type OsqueryTable struct {
	Name      string   `json:"name"`
	URL       string   `json:"url"`
	Platforms []string `json:"platforms"`
	Filter    string
}
