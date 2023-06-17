<!-- manpage-bold-literal.xsl:
     special formatting for manpages rendered from asciidoc+docbook -->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
		xmlns:d="http://docbook.org/ns/docbook"
		version="1.0">

<!-- render literal text as bold (instead of plain or monospace);
     this makes literal text easier to distinguish in manpages
     viewed on a tty -->
<xsl:template match="literal|d:literal">
	<xsl:text>\fB</xsl:text>
	<xsl:apply-templates/>
	<xsl:text>\fR</xsl:text>
</xsl:template>

</xsl:stylesheet>
