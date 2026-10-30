using System;
using Autodesk.AutoCAD.ApplicationServices;
using Autodesk.AutoCAD.Runtime;
using Autodesk.Windows;
using System.Windows.Media.Imaging;

namespace AutoCADMCP
{
    public class App : IExtensionApplication
    {
        public static System.Threading.SynchronizationContext MainThreadContext { get; private set; }

        public void Initialize()
        {
            MainThreadContext = System.Threading.SynchronizationContext.Current;

            if (ComponentManager.Ribbon == null)
            {
                ComponentManager.ItemInitialized += ComponentManager_ItemInitialized;
            }
            else
            {
                CreateRibbon();
            }

            var doc = Application.DocumentManager.MdiActiveDocument;
            if (doc != null)
            {
                doc.Editor.WriteMessage("\n[MCP] AutoCAD MCP Tools Loaded (Port 8965).\n");
            }
        }

        private void ComponentManager_ItemInitialized(object sender, RibbonItemEventArgs e)
        {
            if (ComponentManager.Ribbon != null)
            {
                ComponentManager.ItemInitialized -= ComponentManager_ItemInitialized;
                CreateRibbon();
            }
        }

        public void Terminate()
        {
            Server.SocketServer.Stop();
        }

        private static BitmapSource CreatePlayIcon(int size)
        {
            try
            {
                var visual = new System.Windows.Media.DrawingVisual();
                using (var dc = visual.RenderOpen())
                {
                    // Green rounded background
                    var bgBrush = new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(39, 174, 96));
                    bgBrush.Freeze();
                    dc.DrawRoundedRectangle(bgBrush, null, new System.Windows.Rect(1, 1, size - 2, size - 2), 4, 4);

                    // White play triangle
                    var fgBrush = System.Windows.Media.Brushes.White;
                    var path = new System.Windows.Media.PathGeometry();
                    var figure = new System.Windows.Media.PathFigure
                    {
                        StartPoint = new System.Windows.Point(size * 0.35, size * 0.25),
                        IsClosed = true,
                        IsFilled = true
                    };
                    figure.Segments.Add(new System.Windows.Media.LineSegment(new System.Windows.Point(size * 0.75, size * 0.5), true));
                    figure.Segments.Add(new System.Windows.Media.LineSegment(new System.Windows.Point(size * 0.35, size * 0.75), true));
                    path.Figures.Add(figure);
                    path.Freeze();
                    dc.DrawGeometry(fgBrush, null, path);
                }
                var rtb = new RenderTargetBitmap(size, size, 96, 96, System.Windows.Media.PixelFormats.Pbgra32);
                rtb.Render(visual);
                rtb.Freeze();
                return rtb;
            }
            catch
            {
                return null;
            }
        }

        private static BitmapSource CreateStopIcon(int size)
        {
            try
            {
                var visual = new System.Windows.Media.DrawingVisual();
                using (var dc = visual.RenderOpen())
                {
                    // Red rounded background
                    var bgBrush = new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(231, 76, 60));
                    bgBrush.Freeze();
                    dc.DrawRoundedRectangle(bgBrush, null, new System.Windows.Rect(1, 1, size - 2, size - 2), 4, 4);

                    // White stop square
                    var fgBrush = System.Windows.Media.Brushes.White;
                    double offset = size * 0.28;
                    double rectSize = size - 2 * offset;
                    dc.DrawRoundedRectangle(fgBrush, null, new System.Windows.Rect(offset, offset, rectSize, rectSize), 2, 2);
                }
                var rtb = new RenderTargetBitmap(size, size, 96, 96, System.Windows.Media.PixelFormats.Pbgra32);
                rtb.Render(visual);
                rtb.Freeze();
                return rtb;
            }
            catch
            {
                return null;
            }
        }

        private void CreateRibbon()
        {
            try
            {
                RibbonControl ribbon = ComponentManager.Ribbon;
                if (ribbon == null) return;

                string tabId = "MCP_TAB";
                RibbonTab tab = ribbon.FindTab(tabId);

                if (tab == null)
                {
                    tab = new RibbonTab
                    {
                        Id = tabId,
                        Title = "MCP Tools"
                    };
                    ribbon.Tabs.Add(tab);

                    RibbonPanelSource panelSource = new RibbonPanelSource
                    {
                        Title = "Connection"
                    };
                    RibbonPanel panel = new RibbonPanel
                    {
                        Source = panelSource
                    };
                    tab.Panels.Add(panel);

                    var playIcon32 = CreatePlayIcon(32);
                    var playIcon16 = CreatePlayIcon(16);
                    var stopIcon32 = CreateStopIcon(32);
                    var stopIcon16 = CreateStopIcon(16);

                    RibbonButton btnStart = new RibbonButton
                    {
                        Text = "Start Server",
                        ShowText = true,
                        ShowImage = playIcon32 != null,
                        LargeImage = playIcon32,
                        Image = playIcon16,
                        Size = RibbonItemSize.Large,
                        Orientation = System.Windows.Controls.Orientation.Vertical,
                        CommandHandler = new RelayCommand(StartServer)
                    };
                    
                    RibbonButton btnStop = new RibbonButton
                    {
                        Text = "Stop Server",
                        ShowText = true,
                        ShowImage = stopIcon32 != null,
                        LargeImage = stopIcon32,
                        Image = stopIcon16,
                        Size = RibbonItemSize.Large,
                        Orientation = System.Windows.Controls.Orientation.Vertical,
                        CommandHandler = new RelayCommand(StopServer)
                    };

                    RibbonRowPanel row = new RibbonRowPanel();
                    row.Items.Add(btnStart);
                    row.Items.Add(btnStop);
                    panel.Source.Items.Add(row);
                }

                tab.IsActive = true;
            }
            catch (System.Exception ex)
            {
                var doc = Application.DocumentManager.MdiActiveDocument;
                if (doc != null)
                {
                    doc.Editor.WriteMessage($"\n[MCP] Error creating ribbon: {ex.Message}\n");
                }
            }
        }

        [CommandMethod("STARTMCP")]
        public void StartMcpCommand()
        {
            CreateRibbon();
            Server.SocketServer.Start();
        }

        [CommandMethod("STOPMCP")]
        public void StopMcpCommand()
        {
            Server.SocketServer.Stop();
        }

        [CommandMethod("MCPRIBBON")]
        public void ShowRibbonCommand()
        {
            CreateRibbon();
        }

        private void StartServer(object parameter)
        {
            Server.SocketServer.Start();
        }

        private void StopServer(object parameter)
        {
            Server.SocketServer.Stop();
        }
    }

    public class RelayCommand : System.Windows.Input.ICommand
    {
        private readonly Action<object> _execute;
        public RelayCommand(Action<object> execute) { _execute = execute; }
        public bool CanExecute(object parameter) => true;
        public void Execute(object parameter) => _execute(parameter);
        public event EventHandler CanExecuteChanged { add { } remove { } }
    }
}
