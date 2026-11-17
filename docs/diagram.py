"""Generates docs/architecture.svg. Run: python docs/diagram.py"""
from pathlib import Path
from xml.sax.saxutils import escape

W, H = 1400, 1010
C = {
    "net": "#8C4FFF", "compute": "#ED7D1C", "db": "#3B48CC", "storage": "#3F8624",
    "mgmt": "#E7157B", "sec": "#DD344C", "green": "#1D8102", "amber": "#C45500",
    "ink": "#232F3E", "muted": "#5F6B7A", "line": "#879196",
}
out = []


def text(x, y, s, size=13, color=C["ink"], weight="normal", anchor="start", style=""):
    out.append(f'<text x="{x}" y="{y}" font-size="{size}" fill="{color}" font-weight="{weight}" '
               f'text-anchor="{anchor}" {style}>{escape(s)}</text>')


def rect(x, y, w, h, stroke, fill="#fff", dash=None, rx=8, sw=1.5):
    d = f' stroke-dasharray="{dash}"' if dash else ""
    out.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"{d}/>')


def box(x, y, w, h, color, title, sub="", dash=None):
    rect(x, y, w, h, color, dash=dash)
    out.append(f'<rect x="{x}" y="{y}" width="6" height="{h}" rx="3" fill="{color}"/>')
    ty = y + h / 2 + (-3 if sub else 5)
    text(x + 14, ty, title, 13, C["ink"], "600")
    if sub:
        text(x + 14, ty + 16, sub, 11, C["muted"])


def arrow(x1, y1, x2, y2, color=C["line"], dash=None, both=False, sw=2):
    d = f' stroke-dasharray="{dash}"' if dash else ""
    m = ' marker-start="url(#a-%s)"' % color[1:] if both else ""
    out.append(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{color}" stroke-width="{sw}"{d}{m} marker-end="url(#a-{color[1:]})"/>')


def path(d, color=C["line"], dash=None, sw=2):
    da = f' stroke-dasharray="{dash}"' if dash else ""
    out.append(f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{sw}"{da} marker-end="url(#a-{color[1:]})"/>')


def pill(x, y, s, color):
    w = len(s) * 6.4 + 14
    rect(x - w / 2, y - 12, w, 20, color, "#fff", rx=10, sw=1)
    text(x, y + 2, s, 11, color, "600", "middle")


markers = "".join(
    f'<marker id="a-{c[1:]}" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">'
    f'<path d="M0,0 L10,5 L0,10 z" fill="{c}"/></marker>'
    for c in {C["line"], C["green"], C["amber"], C["db"], C["storage"], C["mgmt"]})

# ---------- Title, users, Route 53 ----------
text(30, 40, "Multi-Region Disaster Recovery - Warm Standby with Route 53 Failover", 22, C["ink"], "700")
text(30, 62, "Primary us-east-1 (active)  ·  Secondary eu-west-1 (warm standby)  ·  RPO < 1 s (Aurora Global)  ·  RTO ~ 2-5 min", 13, C["muted"])

out.append(f'<circle cx="700" cy="105" r="20" fill="#fff" stroke="{C["ink"]}" stroke-width="1.5"/>')
text(700, 111, "Users", 11, C["ink"], "600", "middle")
arrow(700, 125, 700, 148)
box(575, 150, 250, 56, C["net"], "Amazon Route 53", "Failover routing + health checks")

# DNS answers
path("M 600 206 C 520 240, 400 250, 345 302", C["green"])
pill(455, 238, "PRIMARY record (while healthy)", C["green"])
path("M 800 206 C 880 240, 1000 250, 1055 302", C["amber"], dash="6 4")
pill(945, 238, "SECONDARY record (on failure)", C["amber"])

# ---------- Region frames ----------
for rx, label, color in ((30, "us-east-1  ·  PRIMARY (active)", C["green"]),
                         (740, "eu-west-1  ·  SECONDARY (warm standby)", C["amber"])):
    rect(rx, 262, 630, 528, color, "#FBFBFB", dash="8 5", rx=12, sw=2)
    text(rx + 16, 286, label, 15, color, "700")

# ---------- VPC contents (mirrored) ----------
for side in ("pri", "sec"):
    R = 30 if side == "pri" else 740
    rect(R + 14, 298, 602, 270, C["net"], "#F7F3FF", rx=10, sw=1.2)
    text(R + 26, 316, f"VPC {'10.10' if side == 'pri' else '10.20'}.0.0/16  ·  2 AZs  ·  public / app / data subnets", 11, C["net"], "600")
    alb_x = R + 225 if side == "pri" else R + 185
    box(alb_x, 326, 220, 46, C["net"], "Application Load Balancer", "public subnets · /health")
    box(R + 470 if side == "pri" else R + 30, 326, 130, 46, C["net"], "NAT Gateway")
    rect(R + 30, 384, 570, 86, C["compute"], "#FFF8F1", dash="5 4", rx=8)
    text(R + 42, 400, "Auto Scaling group", 11, C["compute"], "600")
    text(R + 590, 400, "private app subnets · target tracking CPU 50%", 11, C["compute"], "600", "end")
    box(R + 70, 410, 200, 48, C["compute"], "EC2  ·  AZ a", "AL2023 · SSM Session Manager")
    if side == "pri":
        box(R + 330, 410, 200, 48, C["compute"], "EC2  ·  AZ b", "min 2 / desired 2")
    else:
        box(R + 330, 410, 200, 48, C["compute"], "EC2  ·  AZ b", "added on failover (1 -> 2+)", dash="5 4")
    arrow(alb_x + 110, 372, alb_x + 110, 383, C["line"])
    if side == "pri":
        box(R + 300, 484, 300, 56, C["db"], "Aurora MySQL Serverless v2", "WRITER  ·  data subnets  ·  Multi-AZ ready")
    else:
        box(R + 15 + 15, 484, 300, 56, C["db"], "Aurora MySQL Serverless v2", "READ-ONLY  ·  promoted to writer on DR")
    text(R + 30, 558, "Gateway endpoints: S3 + DynamoDB  ·  no SSH, no bastion", 11, C["muted"])

# Aurora Global replication
arrow(630, 512, 768, 512, C["db"], sw=2.5)
pill(700, 498, "Aurora Global < 1 s", C["db"])

# ---------- Replicated data services (aligned across the gap) ----------
rows = [(590, "DynamoDB Global Table", "active-active replica", C["db"], "Global Tables", True),
        (650, "S3 bucket", "versioned · assets / uploads", C["storage"], "S3 CRR", False),
        (710, "AWS Backup vault", "daily · 35-day retention", C["storage"], "Backup copy", False)]
for y, title, sub, color, label, both in rows:
    box(480, y, 168, 48, color, title, sub)
    box(752, y, 168, 48, color, title.replace("S3 bucket", "S3 replica bucket"), sub)
    arrow(650, y + 24, 750, y + 24, color, both=both)
    pill(700, y + 8, label, color)

# ---------- Primary-only control plane ----------
box(46, 590, 190, 48, C["sec"], "Secrets Manager", "DB creds · replicated")
box(46, 650, 190, 48, C["mgmt"], "CloudWatch alarm", "HealthCheckStatus < 1")
box(256, 650, 200, 48, C["mgmt"], "EventBridge rule", "forward alarm cross-Region")
box(256, 590, 200, 48, C["mgmt"], "SNS alerts", "email on ALARM / OK")
box(46, 710, 190, 48, C["net"], "Route 53 health check", "HTTP /health every 10 s")
arrow(141, 710, 141, 700, C["mgmt"])
arrow(236, 674, 254, 674, C["mgmt"])
arrow(236, 656, 256, 630, C["mgmt"])

# ---------- Secondary-only control plane ----------
box(940, 590, 200, 48, C["sec"], "Secrets Manager", "replica secret")
box(940, 650, 200, 48, C["mgmt"], "EventBridge rule", "on forwarded alarm")
box(1160, 650, 196, 48, C["compute"], "Lambda: failover", "scale ASG · promote DB")
box(1160, 590, 196, 48, C["mgmt"], "SNS alerts", "runbook result")
box(940, 710, 200, 48, C["storage"], "KMS key", "Aurora encryption")
arrow(1140, 674, 1158, 674, C["mgmt"])
arrow(1258, 650, 1258, 640, C["mgmt"])

# Lambda actions
path("M 1300 650 C 1330 560, 1330 470, 1272 460", C["amber"], dash="6 4")
text(1312, 520, "scale up", 11, C["amber"], "600", "end")
path("M 1180 650 C 1150 600, 1120 560, 1072 541", C["amber"], dash="6 4")
text(1150, 566, "promote", 11, C["amber"], "600")

# Cross-Region alarm forwarding (below the frames)
path("M 356 698 L 356 806 L 1040 806 L 1040 700", C["mgmt"], dash="6 4")
pill(700, 806, "alarm event -> secondary Region event bus", C["mgmt"])

# ---------- Failover sequence ----------
text(30, 852, "Failover sequence", 15, C["ink"], "700")
steps = ["Primary ALB stops answering /health",
         "Route 53 marks PRIMARY unhealthy (~30 s)",
         "DNS now answers with the SECONDARY ALB",
         "CloudWatch alarm -> EventBridge -> Lambda",
         "Lambda scales the standby ASG to prod size",
         "Aurora replica promoted to writer (~1 min)"]
for i, s in enumerate(steps):
    x = 30 + i * 226
    rect(x, 866, 214, 64, C["line"], "#fff", rx=10, sw=1)
    out.append(f'<circle cx="{x + 22}" cy="{898}" r="13" fill="{C["amber"] if i else C["sec"]}"/>')
    text(x + 22, 903, str(i + 1), 13, "#fff", "700", "middle")
    words, line, lines = s.split(), "", []
    for w_ in words:
        if len(line + " " + w_) > 24:
            lines.append(line)
            line = w_
        else:
            line = (line + " " + w_).strip()
    lines.append(line)
    for j, ln in enumerate(lines):
        text(x + 44, 893 + j * 16 - (len(lines) - 2) * 8, ln, 12)

text(30, 960, "Infrastructure as code: one Terraform module deployed to both Regions (same role as a CloudFormation StackSet).", 12, C["muted"])
text(30, 980, "Failback: restore the primary, run a managed Aurora switchover (no data loss), shrink the standby back to 1 instance.", 12, C["muted"])

svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" '
       f'font-family="Amazon Ember, Helvetica, Arial, sans-serif"><defs>{markers}</defs>'
       f'<rect width="{W}" height="{H}" fill="#ffffff"/>' + "".join(out) + "</svg>")
Path(__file__).with_name("architecture.svg").write_text(svg, encoding="utf-8")
print("wrote architecture.svg")
