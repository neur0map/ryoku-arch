function parseEndpoint(value) {
  const text = String(value || "").trim();
  if (text.length === 0) return { address: "*", port: "" };

  const bracketed = text.match(/^\[([^\]]+)\]:(.+)$/);
  if (bracketed) {
    return { address: bracketed[1], port: bracketed[2] };
  }

  const separator = text.lastIndexOf(":");
  if (separator < 0) return { address: text, port: "" };

  return {
    address: text.slice(0, separator) || "*",
    port: text.slice(separator + 1)
  };
}

function formatEndpoint(address, port) {
  if (address.indexOf(":") >= 0) return "[" + address + "]:" + port;
  return address + ":" + port;
}

function parseProcess(line) {
  const match = String(line || "").match(/users:\(\("([^"]+)",pid=([0-9]+)/);
  if (!match) return { process: "", pid: "" };
  return { process: match[1], pid: match[2] };
}

function parseService(line) {
  const match = String(line || "").match(/\bcgroup:([^\s]+)/);
  if (!match) return "";

  const parts = match[1].split("/").filter(part => part.length > 0);
  for (let i = parts.length - 1; i >= 0; i--) {
    if (/\.(service|scope|socket)$/.test(parts[i])) return parts[i];
  }
  return parts[parts.length - 1] || "";
}

function inferPurpose(port, processName, serviceName) {
  const process = String(processName || "").toLowerCase();
  const service = String(serviceName || "").toLowerCase();

  if (process.indexOf("ollama") >= 0) return "Ollama API";
  if (process.indexOf("sshd") >= 0) return "SSH";
  if (process.indexOf("cups") >= 0) return "CUPS printing";
  if (process.indexOf("postgres") >= 0) return "PostgreSQL";
  if (process.indexOf("redis") >= 0) return "Redis";
  if (process.indexOf("mysqld") >= 0 || process.indexOf("mariadbd") >= 0) return "MySQL/MariaDB";
  if (process.indexOf("systemd-resolve") >= 0) return "DNS resolver";
  if (service.indexOf("tailscaled") >= 0) return "Tailscale";
  if (service.indexOf("cups") >= 0) return "CUPS printing";
  if (service.indexOf("systemd-resolved") >= 0 && String(port || "") === "5355") return "LLMNR name resolution";
  if (service.indexOf("systemd-resolved") >= 0) return "DNS resolver";

  const portPurposes = {
    "22": "SSH",
    "53": "DNS resolver",
    "80": "HTTP",
    "443": "HTTPS",
    "631": "CUPS printing",
    "3000": "Development web server",
    "5355": "LLMNR name resolution",
    "5000": "Development web server",
    "5173": "Vite dev server",
    "5432": "PostgreSQL",
    "3306": "MySQL/MariaDB",
    "6379": "Redis",
    "8000": "Development web server",
    "8080": "HTTP proxy/dev server",
    "11434": "Ollama API"
  };

  return portPurposes[String(port || "")] || "TCP listener";
}

function parseListeningSockets(raw) {
  const lines = String(raw || "")
    .split(/\r?\n/)
    .map(line => line.trim())
    .filter(line => line.length > 0);
  const listeners = [];

  for (const line of lines) {
    const fields = line.split(/\s+/);
    if (fields.length < 4 || fields[0].toUpperCase() !== "LISTEN") continue;

    const endpoint = parseEndpoint(fields[3]);
    if (endpoint.port.length === 0 || endpoint.port === "*") continue;

    const proc = parseProcess(line);
    const service = parseService(line);
    const processLabel = proc.process.length > 0
      ? proc.process + (proc.pid.length > 0 ? " (" + proc.pid + ")" : "")
      : service.length > 0
      ? service
      : "unknown process";

    listeners.push({
      protocol: "tcp",
      address: endpoint.address,
      port: endpoint.port,
      endpoint: formatEndpoint(endpoint.address, endpoint.port),
      process: proc.process,
      pid: proc.pid,
      service: service,
      processLabel: processLabel,
      purpose: inferPurpose(endpoint.port, proc.process, service)
    });
  }

  return {
    count: listeners.length,
    listeners: listeners
  };
}

if (typeof module !== "undefined") {
  module.exports = {
    inferPurpose,
    parseEndpoint,
    parseListeningSockets,
    parseProcess,
    parseService
  };
}
