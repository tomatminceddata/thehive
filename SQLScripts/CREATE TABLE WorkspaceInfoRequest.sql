/****** Object:  Table [dbo].[WorkspaceInfoRequest]    Script Date: 9/15/2021 1:08:43 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[WorkspaceInfoRequest](
	[id] [varchar](64) NULL,
	[createdDateTime] [datetime] NULL,
	[status] [varchar](25) NULL,
	[processed] [varchar](25) NULL
) ON [PRIMARY]
GO


